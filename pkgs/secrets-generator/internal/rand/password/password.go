package password

import (
	"crypto/rand"
	"io"
	"math/big"
)

func GeneratePassword(rng io.Reader, charset string, length int) ([]byte, error) {
	max := big.NewInt(int64(len(charset)))
	password := make([]byte, length)

	for i := 0; i < length; i++ {
		idx, err := rand.Int(rng, max)
		if err != nil {
			return nil, err
		}

		password[i] = charset[idx.Int64()]
	}

	return password, nil
}
