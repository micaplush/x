package json_test

import (
	"bytes"
	"context"
	encjson "encoding/json"
	"io"
	"testing"

	"filippo.io/age"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"tbx.at/secrets-generator/internal"
	"tbx.at/secrets-generator/internal/generator/json"
	"tbx.at/secrets-generator/internal/rand/bcrypt"
	"tbx.at/secrets-generator/internal/testutil"
)

type zeroReader struct {
}

func (z *zeroReader) Read(p []byte) (n int, err error) {
	for i := range p {
		p[i] = 0
	}
	return len(p), nil
}

var _ io.Reader = (*zeroReader)(nil)

func TestNestedFunctionCall(t *testing.T) {
	password := "secret"
	rounds := 5

	secret := internal.Secret{
		Generation: internal.GenerationParams{
			JSON: &internal.GenerationParamsJSON{
				Content: testutil.JSONFunctionCall("hashBcrypt", map[string]any{
					"data": testutil.JSONFunctionCall("readSecret", map[string]any{
						"name": "password",
					}),
					"rounds": float64(rounds),
				}),
			},
		},
	}

	secretStore := internal.NewSecretStore([]age.Identity{})
	secretStore.StoreSecret("password", []byte(password))

	completionMap := internal.NewCompletionMap(map[string]internal.Secret{
		"password":       {},
		"objectWithHash": {},
	})

	completionMap.MarkComplete("password")

	gen := &json.GeneratorJSON{
		Completion:  completionMap,
		SecretStore: secretStore,
	}

	expectedHash, err := bcrypt.GenerateFromPassword(&zeroReader{}, []byte(password), rounds)
	require.NoError(t, err)

	expectedBytes, err := encjson.Marshal(string(expectedHash))
	require.NoError(t, err)

	actual := new(bytes.Buffer)
	assert.NoError(t, gen.Generate(context.Background(), &zeroReader{}, secret, actual))

	assert.JSONEq(t, string(expectedBytes), actual.String())
}

func TestNestedObject(t *testing.T) {
	content := map[string]any{
		"nested": map[string]any{
			"objects": "nested objects",
		},
		"objects": map[string]any{
			"nested": map[string]any{},
		},
	}

	secret := internal.Secret{
		Generation: internal.GenerationParams{
			JSON: &internal.GenerationParamsJSON{
				Content: content,
			},
		},
	}

	gen := &json.GeneratorJSON{}

	expectedBytes, err := encjson.Marshal(content)
	require.NoError(t, err)

	actual := new(bytes.Buffer)
	assert.NoError(t, gen.Generate(context.Background(), nil, secret, actual))

	assert.JSONEq(t, string(expectedBytes), actual.String())
}
