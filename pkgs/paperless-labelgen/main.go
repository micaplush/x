package main

import (
	"flag"
	"fmt"
	"log"
	"slices"

	"tbx.at/paperless-labelgen/label"
	"tbx.at/paperless-labelgen/labelprinter"
	"tbx.at/paperless-labelgen/paperless"
)

const assignTag = "assign_asn"

func main() {
	if err := run(); err != nil {
		panic(err)
	}
}

func run() error {
	var assignASN bool
	var id uint
	var passwordFile string
	var printer string
	var url string
	var username string

	flag.BoolVar(&assignASN, "assign-asn", false, "Assign an archive serial number if the document does not have one")
	flag.UintVar(&id, "document-id", 0, "ID of the document to process")
	flag.StringVar(&passwordFile, "password-file", "", "File to read the Paperless user password from")
	flag.StringVar(&printer, "printer", "", "Name of the label printer in CUPS")
	flag.StringVar(&url, "url", "", "Base URL of the Paperless server")
	flag.StringVar(&username, "username", "", "Name of the Paperless user")
	flag.Parse()

	client, err := paperless.NewClient(url, username, passwordFile)
	if err != nil {
		return err
	}

	document, err := client.GetDocument(id)
	if err != nil {
		return err
	}

	if !slices.Contains(document.Tags, assignTag) {
		log.Printf("no %s tag, not assigning ASN or printing label for document ID %d", assignTag, document.ID)
		return nil
	}

	if document.ASN == 0 {
		if !assignASN {
			return fmt.Errorf("no ASN on document %d and not allowed to assign one", id)
		}

		document.ASN, err = client.AssignNextASN(id)
		if err != nil {
			return err
		}
	}

	img, err := label.GenerateLabel(url, document)
	if err != nil {
		return err
	}

	if printer == "" {
		return labelprinter.PrintDryRun(img)
	}

	return labelprinter.Print(printer, img)
}
