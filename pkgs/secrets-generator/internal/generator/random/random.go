package random

import (
	"context"
	"errors"
	"fmt"
	"io"
	"slices"
	"strings"

	"tbx.at/secrets-generator/internal"
	"tbx.at/secrets-generator/internal/rand/password"
)

var (
	ErrEmptyCharset   = errors.New("empty charset for secret generation")
	ErrUnknownCharset = errors.New("unknown charset")
)

var SupportedCharsets = map[string]string{
	"lowercase": "abcdefghijkmnpqrstuvwxyz",
	"numbers":   "123456789",
	"special":   "#$%&@^`~.,:;\"'\\/|_-<>*+!?={[()]}",
	"uppercase": "ABCDEFGHJKLMNPQRSTUVWXYZ",
}

type GeneratorRandom struct {
}

func (gen *GeneratorRandom) Deterministic() bool {
	return true
}

func (gen *GeneratorRandom) Generate(ctx context.Context, rng io.Reader, secret internal.Secret, output io.Writer) error {
	var charset strings.Builder

	charsets := secret.Generation.Random.Charsets

	charsetsOrdered := make([]string, 0, len(charsets))
	for charset := range charsets {
		charsetsOrdered = append(charsetsOrdered, charset)
	}
	slices.Sort(charsetsOrdered)

	for _, name := range charsetsOrdered {
		enabled := charsets[name]

		cs, ok := SupportedCharsets[name]
		if !ok {
			return fmt.Errorf("%w: %s", ErrUnknownCharset, name)
		}

		if enabled {
			charset.WriteString(cs)
		}
	}

	if charset.Len() == 0 {
		return ErrEmptyCharset
	}

	password, err := password.GeneratePassword(rng, charset.String(), secret.Generation.Random.Length)
	if err != nil {
		return err
	}

	_, err = output.Write(password)
	return err
}
