package labelprinter

import (
	"image"
	"image/png"
	"os"
	"os/exec"
)

func Print(printer string, img image.Image) error {
	f, err := os.CreateTemp(os.TempDir(), "paperless-labelgen-")
	if err != nil {
		return err
	}
	defer f.Close()

	if err := png.Encode(f, img); err != nil {
		return err
	}

	cmd := exec.Command("lp", "-d", printer, f.Name())
	cmd.Stdout = os.Stderr
	cmd.Stderr = os.Stderr
	return cmd.Run()
}

func PrintDryRun(img image.Image) error {
	f, err := os.Create("label.png")
	if err != nil {
		return err
	}
	defer f.Close()

	return png.Encode(f, img)
}
