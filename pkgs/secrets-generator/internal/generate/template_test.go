package generate_test

import (
	"crypto/rand"
	"fmt"
	mathrand "math/rand"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"tbx.at/secrets-generator/internal"
	"tbx.at/secrets-generator/internal/rand/argon2id"
	"tbx.at/secrets-generator/internal/rand/bcrypt"
	"tbx.at/secrets-generator/internal/rand/password"
)

const (
	templateName            = "secrets-generator"
	templatePasswordCharset = "abcdefghijklmnopqrstuvwxyz"
)

func TestTemplateExistNoEntropy(t *testing.T) {
	testbed := InitializeTest(t)
	secretName := testbed.GenerateSecretName()

	config := internal.Config{
		PublicKeys: testbed.PublicKeys,
		Secrets: map[string]internal.Secret{
			secretName: {
				Generation: internal.GenerationParams{
					Template: &internal.GenerationParamsTemplate{
						Data: map[string]any{
							"Name": templateName,
						},

						Content: "Hello {{.Name}}!",
					},
				},
			},
		},
		SecretMounts: RandomMounts(map[string]int{
			secretName: 3,
		}),
	}

	testbed.WriteSecret(t, testbed.RecipientsForSecret(config.SecretMounts, secretName), secretName, "Hello secrets-generator!")
	fileContentsBefore := testbed.ReadSecretFile(t, secretName)

	testbed.RunGenerator(t, config)

	fileContentsAfter := testbed.ReadSecretFile(t, secretName)
	assert.Equal(t, fileContentsBefore, fileContentsAfter)
}

func TestTemplateNoFunction(t *testing.T) {
	password, err := password.GeneratePassword(rand.Reader, templatePasswordCharset, 32)
	require.NoError(t, err)

	prefix := "password: "

	testTemplateFunction(t, templateTestParameters{
		Data: map[string]any{
			"Password": string(password),
		},
		Template: prefix + "{{ .Password }}",

		CheckOutput: func(t *testing.T, parameters templateTestCheckParameters) {
			assert.Equal(t, prefix+string(password), parameters.output)

			entropy := parameters.testbed.ReadEntropy(t, parameters.secretName)
			assert.Empty(t, entropy)
		},
	})
}

func TestTemplateFmt(t *testing.T) {
	number := mathrand.Intn(10)

	password, err := password.GeneratePassword(rand.Reader, templatePasswordCharset, 32)
	require.NoError(t, err)

	testTemplateFunction(t, templateTestParameters{
		Data: map[string]any{
			"Number":   number,
			"Password": password,
		},
		Template: `{{ fmt "%s %d" .Password .Number }}`,

		CheckOutput: func(t *testing.T, parameters templateTestCheckParameters) {
			assert.Equal(t, fmt.Sprintf("%s %d", password, number), parameters.output)
		},
	})
}

func TestTemplateHashArgon2id(t *testing.T) {
	password, err := password.GeneratePassword(rand.Reader, templatePasswordCharset, 32)
	require.NoError(t, err)

	testTemplateFunction(t, templateTestParameters{
		Data: map[string]any{
			"Password": password,
		},
		Template: "{{ hashArgon2id .Password 65536 1 16 }}",

		CheckOutput: func(t *testing.T, parameters templateTestCheckParameters) {
			match, _, err := argon2id.CheckHash(string(password), parameters.output)
			assert.NoError(t, err)
			assert.True(t, match)
		},
	})
}

func TestTemplateHashBcrypt(t *testing.T) {
	password, err := password.GeneratePassword(rand.Reader, templatePasswordCharset, 32)
	require.NoError(t, err)

	testTemplateFunction(t, templateTestParameters{
		Data: map[string]any{
			"Password": password,
		},
		Template: "{{ hashBcrypt .Password 5 }}",

		CheckOutput: func(t *testing.T, parameters templateTestCheckParameters) {
			assert.NoError(t, bcrypt.CompareHashAndPassword([]byte(parameters.output), password))
		},
	})
}

func TestTemplateStringReplace(t *testing.T) {
	testTemplateFunction(t, templateTestParameters{
		Data:     map[string]any{},
		Template: `{{ stringReplace "abc" "a" "AA" -1 }}`,

		CheckOutput: func(t *testing.T, parameters templateTestCheckParameters) {
			assert.Equal(t, "AAbc", parameters.output)
		},
	})
}

type templateTestParameters struct {
	Data        map[string]any
	Template    string
	CheckOutput func(t *testing.T, parameters templateTestCheckParameters)
}

type templateTestCheckParameters struct {
	secretName, output string
	testbed            *Testbed
}

func testTemplateFunction(t *testing.T, params templateTestParameters) {
	testbed := InitializeTest(t)
	secretName := testbed.GenerateSecretName()

	config := internal.Config{
		PublicKeys: testbed.PublicKeys,
		Secrets: map[string]internal.Secret{
			secretName: {
				Generation: internal.GenerationParams{
					Template: &internal.GenerationParamsTemplate{
						Data:    params.Data,
						Content: params.Template,
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

	t.Run("output", func(t *testing.T) {
		secretContent := testbed.ReadSecret(t, identities, secretName)
		params.CheckOutput(t, templateTestCheckParameters{
			secretName: secretName,
			output:     secretContent,
			testbed:    testbed,
		})
	})

	t.Run("reproducability", func(t *testing.T) {
		secretFileBefore := testbed.ReadSecretFile(t, secretName)
		entropyFileBefore := testbed.ReadEntropyFile(t, secretName)

		testbed.RunGenerator(t, config)

		secretFileAfter := testbed.ReadSecretFile(t, secretName)
		entropyFileAfter := testbed.ReadEntropyFile(t, secretName)

		assert.Equal(t, secretFileBefore, secretFileAfter)
		assert.Equal(t, entropyFileBefore, entropyFileAfter)
	})
}
