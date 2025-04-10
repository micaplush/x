package generate_test

import (
	"os"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"tbx.at/secrets-generator/internal"
)

const regexDependenciesHash = "hash: " + RegexBcryptHash

func TestDependenciesGenerate(t *testing.T) {
	passwordLength := 32

	testbed := InitializeTest(t)

	passwordSecretName := testbed.GenerateSecretName()
	hashSecretName := testbed.GenerateSecretName()

	config := internal.Config{
		PublicKeys: testbed.PublicKeys,

		Secrets: map[string]internal.Secret{
			passwordSecretName: {
				Generation: internal.GenerationParams{
					Random: &internal.GenerationParamsRandom{
						Length: passwordLength,
						Charsets: map[string]bool{
							"lowercase": true,
						},
					},
				},
			},
			hashSecretName: {
				Generation: internal.GenerationParams{
					Template: &internal.GenerationParamsTemplate{
						Data: map[string]any{
							"PasswordSecret": passwordSecretName,
						},
						Content: `hash: {{ hashBcrypt (readSecret .PasswordSecret) 5 }}`,
					},
				},
			},
		},

		SecretMounts: RandomMounts(map[string]int{
			passwordSecretName: 3,
			hashSecretName:     3,
		}),
	}

	hashIdentities := testbed.IdentitiesForSecret(config.SecretMounts, hashSecretName)

	testbed.RunGenerator(t, config)

	passwordFileContentBefore := testbed.ReadSecretFile(t, passwordSecretName)
	hashSecretBefore := testbed.ReadSecret(t, hashIdentities, hashSecretName)

	assert.Regexp(t, regexDependenciesHash, hashSecretBefore)

	testbed.RunGenerator(t, config)

	passwordFileContentUnchanged := testbed.ReadSecretFile(t, passwordSecretName)
	hashSecretUnchanged := testbed.ReadSecret(t, hashIdentities, hashSecretName)

	assert.Equal(t, passwordFileContentBefore, passwordFileContentUnchanged)
	assert.Equal(t, hashSecretBefore, hashSecretUnchanged)

	require.NoError(t, os.Remove(internal.SecretFilePath(passwordSecretName)))

	testbed.RunGenerator(t, config)

	passwordFileContentChanged := testbed.ReadSecretFile(t, passwordSecretName)
	hashSecretChanged := testbed.ReadSecret(t, hashIdentities, hashSecretName)

	assert.NotEqual(t, passwordFileContentBefore, passwordFileContentChanged)
	assert.NotEqual(t, hashSecretBefore, hashSecretChanged)

	assert.Regexp(t, regexDependenciesHash, hashSecretChanged)
}
