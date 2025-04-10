package generate_test

import (
	"context"
	"fmt"
	"testing"

	"github.com/stretchr/testify/assert"
	"tbx.at/secrets-generator/internal"
	"tbx.at/secrets-generator/internal/generate"
	"tbx.at/secrets-generator/internal/generator/random"
)

func TestRandomGenerate(t *testing.T) {
	secretLength := 32

	testbed := InitializeTest(t)
	secretName := testbed.GenerateSecretName()

	config := internal.Config{
		PublicKeys: testbed.PublicKeys,
		Secrets: map[string]internal.Secret{
			secretName: {
				Generation: internal.GenerationParams{
					Random: &internal.GenerationParamsRandom{
						Length:   secretLength,
						Charsets: RandomCharsets(),
					},
				},
			},
		},
		SecretMounts: RandomMounts(map[string]int{
			secretName: 3,
		}),
	}

	identities := testbed.IdentitiesForSecret(config.SecretMounts, secretName)

	testbed.RunGenerator(t, config)

	secretContent := testbed.ReadSecret(t, identities, secretName)
	assert.Len(t, secretContent, secretLength)
}

func TestRandomModified(t *testing.T) {
	secretLength := 32

	testbed := InitializeTest(t)
	secretName := testbed.GenerateSecretName()

	config := internal.Config{
		PublicKeys: testbed.PublicKeys,
		Secrets: map[string]internal.Secret{
			secretName: {
				Generation: internal.GenerationParams{
					Random: &internal.GenerationParamsRandom{
						Length:   secretLength,
						Charsets: RandomCharsets(),
					},
				},
			},
		},
		SecretMounts: RandomMounts(map[string]int{
			secretName: 3,
		}),
	}

	charsets := config.Secrets[secretName].Generation.Random.Charsets
	charsets["uppercase"] = false

	var hasCharsets bool
	for _, enabled := range charsets {
		if enabled {
			hasCharsets = true
			break
		}
	}
	if !hasCharsets {
		charsets["lowercase"] = true
	}

	testbed.RunGenerator(t, config)

	contentBefore := testbed.ReadSecretFile(t, secretName)
	charsets["uppercase"] = true

	testbed.RunGenerator(t, config)

	contentAfter := testbed.ReadSecretFile(t, secretName)
	assert.NotEqual(t, contentBefore, contentAfter)
}

func TestRandomGenerateUnmodified(t *testing.T) {
	secretLength := 32

	testbed := InitializeTest(t)
	secretName := testbed.GenerateSecretName()

	config := internal.Config{
		PublicKeys: testbed.PublicKeys,
		Secrets: map[string]internal.Secret{
			secretName: {
				Generation: internal.GenerationParams{
					Random: &internal.GenerationParamsRandom{
						Length:   secretLength,
						Charsets: RandomCharsets(),
					},
				},
			},
		},
		SecretMounts: RandomMounts(map[string]int{
			secretName: 3,
		}),
	}

	testbed.RunGenerator(t, config)

	contentBefore := testbed.ReadSecretFile(t, secretName)

	testbed.RunGenerator(t, config)

	contentAfter := testbed.ReadSecretFile(t, secretName)
	assert.Equal(t, contentBefore, contentAfter)
}

func TestRandomEmptyCharset(t *testing.T) {
	secretLength := 32

	testbed := InitializeTest(t)
	secretName := testbed.GenerateSecretName()

	config := internal.Config{
		PublicKeys: testbed.PublicKeys,
		Secrets: map[string]internal.Secret{
			secretName: {
				Generation: internal.GenerationParams{
					Random: &internal.GenerationParamsRandom{
						Length:   secretLength,
						Charsets: map[string]bool{},
					},
				},
			},
		},
		SecretMounts: RandomMounts(map[string]int{
			secretName: 3,
		}),
	}

	err := generate.Run(context.Background(), IdentityFileName, config)
	assert.ErrorContains(t, err, fmt.Sprintf("while generating secret %s: %s", secretName, random.ErrEmptyCharset.Error()))
}
