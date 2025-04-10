package template

import (
	"context"
	"errors"
	"fmt"
	"io"
	"strings"
	texttemplate "text/template"

	"tbx.at/secrets-generator/internal"
	"tbx.at/secrets-generator/internal/rand/argon2id"
	"tbx.at/secrets-generator/internal/rand/bcrypt"
)

var ErrTemplateExecutionCancelled = errors.New("template execution cancelled")

type GeneratorTemplate struct {
	Completion  *internal.CompletionMap
	SecretStore *internal.SecretStore
}

func (gen *GeneratorTemplate) Deterministic() bool {
	return true
}

func (gen *GeneratorTemplate) Generate(ctx context.Context, rng io.Reader, secret internal.Secret, output io.Writer) error {
	tmpl, err := texttemplate.New("").
		Funcs(texttemplate.FuncMap{
			"fmt": fmt.Sprintf,

			"hashArgon2id": func(data any, memory, iterations uint32, parallelism uint8) (string, error) {
				var str string

				switch data := data.(type) {
				case []byte:
					str = string(data)
				case string:
					str = data
				default:
					str = fmt.Sprint(data)
				}

				return argon2id.CreateHash(rng, str, &argon2id.Params{
					Memory:      memory,
					Iterations:  iterations,
					Parallelism: parallelism,
					SaltLength:  16,
					KeyLength:   32,
				})
			},

			"hashBcrypt": func(data any, rounds int) (string, error) {
				var bytes []byte

				switch data := data.(type) {
				case []byte:
					bytes = data
				case string:
					bytes = []byte(data)
				default:
					bytes = []byte(fmt.Sprint(data))
				}

				hash, err := bcrypt.GenerateFromPassword(rng, bytes, rounds)
				if err != nil {
					return "", err
				}

				return string(hash), nil
			},

			"readSecret": func(name string) ([]byte, error) {
				select {
				case <-gen.Completion.Done(name):
				case <-ctx.Done():
					return nil, ErrTemplateExecutionCancelled
				}

				return gen.SecretStore.LoadSecret(name)
			},

			"stringReplace": strings.Replace,
		}).
		Parse(secret.Generation.Template.Content)

	if err != nil {
		return err
	}

	return tmpl.Execute(output, secret.Generation.Template.Data)
}
