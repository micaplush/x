package generate_test

import (
	"testing"

	"github.com/stretchr/testify/assert"
	"tbx.at/secrets-generator/internal"
)

func TestScriptExist(t *testing.T) {
	testbed := InitializeTest(t)
	secretName := testbed.GenerateSecretName()

	config := internal.Config{
		PublicKeys: testbed.PublicKeys,
		Secrets: map[string]internal.Secret{
			secretName: {
				Generation: internal.GenerationParams{
					Script: &internal.GenerationParamsScript{
						Program: "date",
					},
				},
			},
		},
		SecretMounts: RandomMounts(map[string]int{
			secretName: 3,
		}),
	}

	testbed.WriteSecret(t, testbed.RecipientsForSecret(config.SecretMounts, secretName), secretName, `
		dummy content for the existing secret

		this won't be checked
	`)

	contentBefore := testbed.ReadSecretFile(t, secretName)

	testbed.RunGenerator(t, config)

	contentAfter := testbed.ReadSecretFile(t, secretName)
	assert.Equal(t, contentBefore, contentAfter)
}

func TestScriptGenerate(t *testing.T) {
	testbed := InitializeTest(t)
	secretName := testbed.GenerateSecretName()

	config := internal.Config{
		PublicKeys: testbed.PublicKeys,
		Secrets: map[string]internal.Secret{
			secretName: {
				Generation: internal.GenerationParams{
					Script: &internal.GenerationParamsScript{
						Program: "date",
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
	assert.NotEmpty(t, secretContent)

	assert.NoFileExists(t, internal.EntropyFilePath(secretName))
}

func TestScriptGenerateUnmodified(t *testing.T) {
	testbed := InitializeTest(t)
	secretName := testbed.GenerateSecretName()

	config := internal.Config{
		PublicKeys: testbed.PublicKeys,
		Secrets: map[string]internal.Secret{
			secretName: {
				Generation: internal.GenerationParams{
					Script: &internal.GenerationParamsScript{
						Program: "date",
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
