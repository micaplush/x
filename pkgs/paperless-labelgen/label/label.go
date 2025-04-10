package label

import (
	"fmt"
	"image"
	"image/color"
	"net/url"
	"os"
	"path/filepath"
	"strconv"
	"time"

	"github.com/fogleman/gg"
	"github.com/skip2/go-qrcode"
	"tbx.at/paperless-labelgen/paperless"
)

const (
	scaleFactor = 4

	canvasWidth  = 380
	canvasHeight = 235

	qrMarginVertical   = 30
	qrMarginHorizontal = 20

	fontSize = 24

	lineMargin = 5
)

const fontDir = "share/fonts/truetype"

var FontPath string

func GenerateLabel(paperlessURL string, document paperless.Document) (image.Image, error) {
	ctx := gg.NewContext(canvasWidth*scaleFactor, canvasHeight*scaleFactor)

	ctx.SetColor(color.White)
	ctx.Clear()
	ctx.SetColor(color.Black)

	link, err := url.JoinPath(paperlessURL, "asn", strconv.Itoa(int(document.ASN)), "/")
	if err != nil {
		return nil, err
	}

	qr, err := qrcode.New(link, qrcode.High)
	if err != nil {
		return nil, err
	}
	qr.DisableBorder = true

	qrImg := qr.Image(ctx.Height() - qrMarginVertical*2*scaleFactor)
	ctx.DrawImage(qrImg, qrMarginHorizontal*scaleFactor, qrMarginVertical*scaleFactor)

	textOffsetX := float64(qrImg.Bounds().Dx() + qrMarginHorizontal*2*scaleFactor)

	lines := []string{
		fmt.Sprintf("ASN%03d", document.ASN),
		fmt.Sprintf("ID: %d", document.ID),
		document.Added.Format(time.DateOnly),
	}

	fontSize := float64(fontSize * scaleFactor)

	if FontPath == "" {
		FontPath = os.Getenv("LABELGEN_FONT")
	}

	faceRegular, err := gg.LoadFontFace(filepath.Join(FontPath, fontDir, "CourierPrime-Regular.ttf"), fontSize)
	if err != nil {
		return nil, err
	}

	faceBold, err := gg.LoadFontFace(filepath.Join(FontPath, fontDir, "CourierPrime-Bold.ttf"), fontSize)
	if err != nil {
		return nil, err
	}

	ctx.SetFontFace(faceBold)
	_, h1 := ctx.MeasureString(lines[0])

	ctx.SetFontFace(faceRegular)
	_, h2 := ctx.MeasureString(lines[1])
	_, h3 := ctx.MeasureString(lines[2])

	lineMargin := float64(lineMargin * scaleFactor)
	textHeight := h1 + h2 + h3 + lineMargin*2

	textOffsetY := float64(ctx.Height())/2 - textHeight/2

	ctx.Translate(textOffsetX, textOffsetY)

	ctx.SetFontFace(faceBold)

	ctx.Translate(0, h1)
	ctx.DrawString(lines[0], 0, 0)

	ctx.SetFontFace(faceRegular)

	ctx.Translate(0, lineMargin+h2)
	ctx.DrawString(lines[1], 0, 0)

	ctx.Translate(0, lineMargin+h3)
	ctx.DrawString(lines[2], 0, 0)

	return ctx.Image(), nil
}
