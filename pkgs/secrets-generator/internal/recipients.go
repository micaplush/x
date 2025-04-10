package internal

import (
	"strings"

	"filippo.io/age"
	"filippo.io/age/agessh"
)

func ParseRecipients(publicKeys map[string][]string) (map[string][]age.Recipient, error) {
	recipients := make(map[string][]age.Recipient)

	for hostname, hostPubKeys := range publicKeys {
		hostRecipients := make([]age.Recipient, 0, len(hostPubKeys))

		for _, publicKey := range hostPubKeys {
			var r age.Recipient
			var err error

			if strings.HasPrefix(publicKey, "age1") {
				r, err = age.ParseX25519Recipient(publicKey)
			} else {
				r, err = agessh.ParseRecipient(publicKey)
			}

			if err != nil {
				return nil, err
			}

			hostRecipients = append(hostRecipients, r)
		}

		recipients[hostname] = hostRecipients
	}

	return recipients, nil
}
