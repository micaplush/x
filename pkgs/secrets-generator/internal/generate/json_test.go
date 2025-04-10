package generate_test

import (
	"bytes"
	"crypto/rand"
	"encoding/json"
	"fmt"
	mathrand "math/rand"
	"os"
	"os/exec"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"tbx.at/secrets-generator/internal"
	"tbx.at/secrets-generator/internal/rand/argon2id"
	"tbx.at/secrets-generator/internal/rand/password"
	"tbx.at/secrets-generator/internal/testutil"
)

func TestJSONExistNoEntropy(t *testing.T) {
	testbed := InitializeTest(t)
	secretName := testbed.GenerateSecretName()

	content := "Hello secrets-generator!"

	config := internal.Config{
		PublicKeys: testbed.PublicKeys,
		Secrets: map[string]internal.Secret{
			secretName: {
				Generation: internal.GenerationParams{
					JSON: &internal.GenerationParamsJSON{
						Content: content,
					},
				},
			},
		},
		SecretMounts: RandomMounts(map[string]int{
			secretName: 3,
		}),
	}

	hostIdentities := testbed.RecipientsForSecret(config.SecretMounts, secretName)

	testbed.WriteSecret(t, hostIdentities, secretName, fmt.Sprintf("\"%s\"\n", content))
	fileContentsBefore := testbed.ReadSecretFile(t, secretName)

	testbed.RunGenerator(t, config)

	fileContentsAfter := testbed.ReadSecretFile(t, secretName)
	assert.Equal(t, fileContentsBefore, fileContentsAfter)
}

func TestJSONDeterministicObjectProcessing(t *testing.T) {
	testbed := InitializeTest(t)
	secretName := testbed.GenerateSecretName()

	content := map[string]any{}
	for i := 0; i < 5; i++ {
		content[fmt.Sprintf("key_%d", i)] = testutil.JSONFunctionCall("hashBcrypt", map[string]any{
			"data":   fmt.Sprintf("value_%d", i),
			"rounds": float64(5),
		})
	}

	config := internal.Config{
		PublicKeys: testbed.PublicKeys,
		Secrets: map[string]internal.Secret{
			secretName: {
				Generation: internal.GenerationParams{
					JSON: &internal.GenerationParamsJSON{
						Content: content,
					},
				},
			},
		},
		SecretMounts: RandomMounts(map[string]int{
			secretName: 3,
		}),
	}

	testbed.RunGenerator(t, config)

	fileContentsBefore := testbed.ReadSecretFile(t, secretName)

	testbed.RunGenerator(t, config)

	fileContentsAfter := testbed.ReadSecretFile(t, secretName)
	assert.Equal(t, fileContentsBefore, fileContentsAfter)
}

func TestJSONNoFunction(t *testing.T) {
	password, err := password.GeneratePassword(rand.Reader, templatePasswordCharset, 32)
	require.NoError(t, err)

	content := map[string]any{
		"password": password,
		"hello":    "world",
	}

	expected, err := json.MarshalIndent(content, "  ", "  ")
	require.NoError(t, err)

	testJSONFunction(t, jsonTestParameters{
		Content: content,

		CheckOutput: func(t *testing.T, parameters jsonTestCheckParameters) {
			assert.JSONEq(t, string(expected), parameters.output)

			entropy := parameters.testbed.ReadEntropy(t, parameters.secretName)
			assert.Empty(t, entropy)
		},
	})
}

func TestJSONFmt(t *testing.T) {
	number := mathrand.Intn(10)

	password, err := password.GeneratePassword(rand.Reader, templatePasswordCharset, 32)
	require.NoError(t, err)

	testJSONFunction(t, jsonTestParameters{
		Content: testutil.JSONFunctionCall("fmt", map[string]any{
			"format": "%s %.f",
			"args": []any{
				password,
				float64(number),
			},
		}),

		CheckOutput: func(t *testing.T, parameters jsonTestCheckParameters) {
			assert.JSONEq(t, fmt.Sprintf(`"%s %d"`, password, number), parameters.output)
		},
	})
}

func TestJSONHashArgon2id(t *testing.T) {
	password, err := password.GeneratePassword(rand.Reader, templatePasswordCharset, 32)
	require.NoError(t, err)

	testJSONFunction(t, jsonTestParameters{
		Content: testutil.JSONFunctionCall("hashArgon2id", map[string]any{
			"data":        string(password),
			"memory":      float64(65536),
			"iterations":  float64(1),
			"parallelism": float64(16),
		}),

		CheckOutput: func(t *testing.T, parameters jsonTestCheckParameters) {
			var hash string
			assert.NoError(t, json.Unmarshal([]byte(parameters.output), &hash))

			match, _, err := argon2id.CheckHash(string(password), hash)
			assert.NoError(t, err)
			assert.True(t, match)
		},
	})
}

func TestJSONHashBcrypt(t *testing.T) {
	password, err := password.GeneratePassword(rand.Reader, templatePasswordCharset, 32)
	require.NoError(t, err)

	testJSONFunction(t, jsonTestParameters{
		Content: testutil.JSONFunctionCall("hashBcrypt", map[string]any{
			"data":   string(password),
			"rounds": float64(5),
		}),

		CheckOutput: func(t *testing.T, parameters jsonTestCheckParameters) {
			var hash string
			assert.NoError(t, json.Unmarshal([]byte(parameters.output), &hash))

			assert.Regexp(t, RegexBcryptHash, hash)

			hashParams := hash[0:29]

			mkpasswdCmd := exec.Command("mkpasswd", "-S", hashParams, string(password))
			mkpasswdCmd.Stderr = os.Stderr
			rehashed, err := mkpasswdCmd.Output()
			assert.NoError(t, err)
			expected := string(bytes.TrimSpace(rehashed))

			assert.Equal(t, expected, hash)
		},
	})
}

type jsonTestParameters struct {
	Content     any
	CheckOutput func(t *testing.T, parameters jsonTestCheckParameters)
}

type jsonTestCheckParameters struct {
	secretName, output string
	testbed            *Testbed
}

func testJSONFunction(t *testing.T, params jsonTestParameters) {
	testbed := InitializeTest(t)
	secretName := testbed.GenerateSecretName()

	config := internal.Config{
		PublicKeys: testbed.PublicKeys,
		Secrets: map[string]internal.Secret{
			secretName: {
				Generation: internal.GenerationParams{
					JSON: &internal.GenerationParamsJSON{
						Content: params.Content,
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
		params.CheckOutput(t, jsonTestCheckParameters{
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
