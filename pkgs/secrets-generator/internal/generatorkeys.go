package internal

import (
	"fmt"
	"os"

	"filippo.io/age"
)

func ParseGeneratorKeys(identityPath string) ([]age.Identity, []age.Recipient, error) {
	identityFile, err := os.Open(identityPath)
	if err != nil {
		return nil, nil, err
	}
	defer identityFile.Close()

	identities, err := age.ParseIdentities(identityFile)
	if err != nil {
		return nil, nil, err
	}

	recipients := make([]age.Recipient, len(identities))
	for i, id := range identities {
		if id, ok := id.(*age.X25519Identity); ok {
			recipients[i] = id.Recipient()
		} else {
			return nil, nil, fmt.Errorf("identity number %d was not of type *age.X25519Identity (cannot handle other types of identities currently)", i+1)
		}
	}

	return identities, recipients, nil
}
