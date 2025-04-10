package generate

import (
	"bytes"
	"context"
	"crypto/rand"
	"errors"
	"fmt"
	"io"
	"os"
	"path/filepath"

	"filippo.io/age"
	"golang.org/x/sync/errgroup"
	"tbx.at/secrets-generator/internal"
	"tbx.at/secrets-generator/internal/generator"
	"tbx.at/secrets-generator/internal/generator/json"
	"tbx.at/secrets-generator/internal/generator/random"
	"tbx.at/secrets-generator/internal/generator/script"
	"tbx.at/secrets-generator/internal/generator/template"
)

const (
	ageFileCreateMode   = 0660
	directoreCreateMode = 0770
)

// Run generates or regenerates secrets in the current working directory as needed.
// This function amounts to the core of the program.
func Run(ctx context.Context, identityPath string, config internal.Config) error {
	// Parse the keys used by the generator to decrypt any secret.
	generatorIdentities, generatorRecipients, err := internal.ParseGeneratorKeys(identityPath)
	if err != nil {
		return err
	}

	// Parse the public keys of hosts that can receive secrets.
	recipients, err := internal.ParseRecipients(config.PublicKeys)
	if err != nil {
		return err
	}

	// Initialize some data structures.

	completionMap := internal.NewCompletionMap(config.Secrets)
	secretStore := internal.NewSecretStore(generatorIdentities)

	generateGroup, generateCtx := errgroup.WithContext(ctx)

	// Initialize the generators.

	generatorJSON := &json.GeneratorJSON{
		Completion:  completionMap,
		SecretStore: secretStore,
	}

	generatorRandom := &random.GeneratorRandom{}
	generatorScript := &script.GeneratorScript{}

	generatorTemplate := &template.GeneratorTemplate{
		Completion:  completionMap,
		SecretStore: secretStore,
	}

	// Iterate over all secrets and start a goroutine to generate it if needed.
	for _secretName, _secret := range config.Secrets {
		secretName := _secretName
		secret := _secret

		// Get the relevant paths.
		entropyFilePath := internal.EntropyFilePath(secretName)
		secretFilePath := internal.SecretFilePath(secretName)

		// Figure out what generator to use.
		var generator generator.Generator
		if secret.Generation.JSON != nil {
			generator = generatorJSON
		} else if secret.Generation.Random != nil {
			generator = generatorRandom
		} else if secret.Generation.Script != nil {
			generator = generatorScript
		} else if secret.Generation.Template != nil {
			generator = generatorTemplate
		} else {
			// If we have no generation options, the secret is not automatically generated.
			// Just mark it as complete then and move on.
			completionMap.MarkComplete(secretName)
			continue
		}

		generate := func() error {
			// rng holds the entropy source to be used in the final secret generation step.
			rng := rand.Reader

			// If the generator can produce deterministic output, we check if it's necessary to regenerate the secret.
			// We do this by feeding the generator the same entropy as last time the secret was generated.
			// If it doesn't error and the output is the same, we know that the secret hasn't changed.
			// If it runs into an error or the output is not the same, we generate the secret again with fresh entropy and record bytes read from that entropy.
			if generator.Deterministic() {
				// hasChanged holds whether the generated output needs regeneration (because of changes or errors).
				var hasChanged bool

				// entropy holds a reader for the entropy used last time the secret was generated.
				var entropy io.Reader

				// Try opening and decrypting the entropy file.
				entropyFile, err := os.Open(entropyFilePath)
				if err == nil {
					entropy, err = age.Decrypt(entropyFile, generatorIdentities...)
					if err != nil {
						return err
					}
				} else if errors.Is(err, os.ErrNotExist) {
					// If no entropy file exists, use an empty reader instead.
					entropy = new(bytes.Reader)
				} else {
					return err
				}

				// Generate the secret into a buffer for comparison.
				generated := new(bytes.Buffer)
				err = generator.Generate(generateCtx, entropy, secret, generated)

				// We don't need the entropy file open for reading anymore, so close it.
				if entropyFile != nil {
					_ = entropyFile.Close()
				}

				if err != nil {
					// If we ran into an error, we can assume that the secret has changed (because a successfully generated secret doesn't result in an error).
					// A likely source of errors is that the amount of entropy read during generation has increased, so we hit the end of the entropy file.
					hasChanged = true
				} else {
					// If we didn't run into an error, the secret was generated successfully with the old entropy.

					// Load the current secret for comparison.

					// Normally we would wait for completion before loading a secret.
					// There's no need to wait for completion here since we're loading the secret currently being generated.

					// Loading it into the secret store is also fine:
					// If it's unchanged, it won't be regenerated and the stored version is current.
					// If it has changed, it will be regenerated and stored before we mark it as complete, so the stale entry in the secret store is replaced before anyone reads it.
					existing, err := secretStore.LoadSecret(secretName)
					if err != nil {
						// If there is an error the secret file doesn't exist or is somehow borked and we should probably regenerate it.
						hasChanged = true
					} else {
						// If all goes well loading the secret, actually compare it to the version generated with the same entropy.
						// If they are the same, the secret hasn't changed.
						// If they are different, the secret has changed and needs to be regenerated.
						hasChanged = !bytes.Equal(generated.Bytes(), existing)
					}

				}

				// If the secret hasn't changed, mark it as complete and we're done.
				if !hasChanged {
					completionMap.MarkComplete(secretName)
					return nil
				}

				// Otherwise we need to regenerate.
				// Set up the rng variable with an entropy source that records to a file.

				// Create the entropy file.

				if err := os.MkdirAll(filepath.Dir(entropyFilePath), directoreCreateMode); err != nil {
					return err
				}

				entropyFile, err = os.Create(entropyFilePath)
				if err != nil {
					return err
				}
				defer entropyFile.Close()

				// Encrypt it in such a way that only the generator can read it.
				// Hosts don't ever need to access this file, so it doesn't make sense to encrypt it for them.
				entropyWriter, err := age.Encrypt(entropyFile, generatorRecipients...)
				if err != nil {
					return err
				}
				defer entropyWriter.Close()

				// rng becomes a reader for cryptographically secure randomness that also writes the bytes it reads to the encrypted entropy file.
				rng = io.TeeReader(rand.Reader, entropyWriter)
			} else {
				// If we end up here then the generator cannot produce deterministic output.
				// In this case, to regenerate or not is a simple question of whether the secret file exists.
				// No entropy file is recorded in this case.

				if _, err := os.Stat(secretFilePath); err == nil {
					completionMap.MarkComplete(secretName)
					return nil
				} else if !errors.Is(err, os.ErrNotExist) {
					return err
				}
			}

			// Find the recipients for the secret.
			// This always includes the generator itself (so that it can decrypt secrets in the future) and all of the hosts that have the secret mounted.

			var secretRecipients []age.Recipient
			secretRecipients = append(secretRecipients, generatorRecipients...)

			for mountName, mount := range config.SecretMounts {
				if mount.Secret == secretName {
					hostRecipients, found := recipients[mount.Host]
					if !found {
						return fmt.Errorf("unknown host in secret mount: mount=%s secret=%s host=%s", mountName, secretName, mount.Host)
					}

					secretRecipients = append(secretRecipients, hostRecipients...)
				}
			}

			// Create the secret file.

			if err := os.MkdirAll(filepath.Dir(secretFilePath), directoreCreateMode); err != nil {
				return err
			}

			secretFile, err := os.Create(secretFilePath)
			if err != nil {
				return err
			}

			// Encrypt the secret file for the previously determined recipients.

			secretWriter, err := age.Encrypt(secretFile, secretRecipients...)
			if err != nil {
				return err
			}

			// The secret will be generated directly into the encrypted file and into an unencrypted buffer.
			// The contents of the buffer will be stored into the secret store later.
			// This avoids the need to read and decrypt the secret file if another secret needs to load the current secret.
			generated := new(bytes.Buffer)
			writer := io.MultiWriter(secretWriter, generated)

			// Actually generate the secret.
			if err := generator.Generate(generateCtx, rng, secret, writer); err != nil {
				return err
			}

			// Flush the age writer and close the secret file gracefully.
			// We don't handle errors during closing for the entropy file because it's inconvenient in the case where we don't have an entropy file.
			// I think it's fine like that.

			if err := secretWriter.Close(); err != nil {
				return err
			}

			if err := secretFile.Close(); err != nil {
				return err
			}

			// Store the secret so that other secret generation goroutines can get its content.
			secretStore.StoreSecret(secretName, generated.Bytes())

			// Mark this secret as complete.
			// Other secret generation goroutines won't try to load this secret until it's marked as complete.
			completionMap.MarkComplete(secretName)

			return nil
		}

		generateGroup.Go(func() error {
			if err := generate(); err != nil {
				return fmt.Errorf("while generating secret %s: %w", secretName, err)
			}

			return nil
		})
	}

	return generateGroup.Wait()
}
