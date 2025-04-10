package internal

import (
	"io"
	"os"
	"sync"

	"filippo.io/age"
)

type SecretStore struct {
	data  map[string][]byte
	mutex sync.Mutex

	identities []age.Identity
}

func (c *SecretStore) LoadSecret(name string) ([]byte, error) {
	c.mutex.Lock()
	defer c.mutex.Unlock()

	data, found := c.data[name]
	if found {
		return data, nil
	}

	f, err := os.Open(SecretFilePath(name))
	if err != nil {
		return nil, err
	}
	defer f.Close()

	reader, err := age.Decrypt(f, c.identities...)
	if err != nil {
		return nil, err
	}

	data, err = io.ReadAll(reader)
	if err != nil {
		return nil, err
	}

	c.data[name] = data

	return data, nil
}

func (c *SecretStore) StoreSecret(name string, data []byte) {
	c.mutex.Lock()
	defer c.mutex.Unlock()

	c.data[name] = data
}

func NewSecretStore(identities []age.Identity) *SecretStore {
	return &SecretStore{
		data: make(map[string][]byte),

		identities: identities,
	}
}
