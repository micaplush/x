package generator

import (
	"context"
	"io"

	"tbx.at/secrets-generator/internal"
)

type Generator interface {
	Deterministic() bool
	Generate(ctx context.Context, rng io.Reader, secret internal.Secret, output io.Writer) error
}
