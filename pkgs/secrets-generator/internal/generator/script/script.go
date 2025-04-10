package script

import (
	"context"
	"io"
	"os"
	"os/exec"

	"tbx.at/secrets-generator/internal"
)

type GeneratorScript struct {
}

func (gen *GeneratorScript) Deterministic() bool {
	return false
}

func (gen *GeneratorScript) Generate(ctx context.Context, rng io.Reader, secret internal.Secret, output io.Writer) error {
	cmd := exec.CommandContext(ctx, secret.Generation.Script.Program)
	cmd.Stderr = os.Stderr
	cmd.Stdout = output
	return cmd.Run()
}
