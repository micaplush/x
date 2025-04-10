package generate_test

import (
	"context"
	"fmt"
	"io"
	"math/rand"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"filippo.io/age"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"tbx.at/secrets-generator/internal"
	"tbx.at/secrets-generator/internal/generate"
	"tbx.at/secrets-generator/internal/generator/random"
)

const secretNameCharset = "abc"

const (
	IdentityFileName = "identity"

	RegexBcryptHash = `\$2a\$05\$[\w\./]{53}`
)

const (
	HostDrizzler  = "drizzler"
	HostFlyfish   = "flyfish"
	HostMaws      = "maws"
	HostScrapper  = "scrapper"
	HostSteelhead = "steelhead"
)

var Hosts = []string{
	HostDrizzler,
	HostFlyfish,
	HostMaws,
	HostScrapper,
	HostSteelhead,
}

type Testbed struct {
	WorkingDir string

	Identities map[string][]age.Identity
	PublicKeys map[string][]string
	Recipients map[string][]age.Recipient

	GeneratorIdentities []*age.X25519Identity

	generatedSecretNames map[string]bool
}

func (tb *Testbed) GenerateSecretName() string {
	for {
		n := rand.Intn(3) + 1
		parts := make([]string, n)
		for i := 0; i < n; i++ {
			parts[i] = string(secretNameCharset[rand.Intn(len(secretNameCharset))])
		}
		name := strings.Join(parts, string(filepath.Separator))

		if tb.generatedSecretNames[name] {
			continue
		}

		tb.generatedSecretNames[name] = true

		return name
	}
}

func (tb *Testbed) IdentitiesForSecret(secretMounts map[string]internal.SecretMount, secretName string) []age.Identity {
	mounts := mountsForSecret(secretMounts, secretName)
	var identities []age.Identity
	for _, mount := range mounts {
		identities = append(identities, tb.Identities[mount.Host]...)
	}
	return identities
}

func (tb *Testbed) RecipientsForSecret(secretMounts map[string]internal.SecretMount, secretName string) []age.Recipient {
	mounts := mountsForSecret(secretMounts, secretName)
	var recipients []age.Recipient
	for _, mount := range mounts {
		recipients = append(recipients, tb.Recipients[mount.Host]...)
	}
	return recipients
}

func mountsForSecret(secretMounts map[string]internal.SecretMount, secretName string) []internal.SecretMount {
	var mounts []internal.SecretMount
	for _, mount := range secretMounts {
		if mount.Secret == secretName {
			mounts = append(mounts, mount)
		}
	}
	return mounts
}

func (tb *Testbed) ReadEntropy(t *testing.T, secretName string) []byte {
	var lastRead *[]byte
	entropyFilePath := internal.EntropyFilePath(secretName)

	for _, identity := range tb.GeneratorIdentities {
		entropyFile, err := os.Open(entropyFilePath)
		require.NoError(t, err)

		entropyReader, err := age.Decrypt(entropyFile, identity)
		require.NoError(t, err)

		entropy, err := io.ReadAll(entropyReader)
		require.NoError(t, err)

		require.NoError(t, entropyFile.Close())

		if lastRead == nil {
			lastRead = &entropy
		}

		assert.Equal(t, *lastRead, entropy, "entropy reads the same for all recipients")
	}

	return *lastRead
}

func (tb *Testbed) ReadEntropyFile(t *testing.T, secretName string) []byte {
	content, err := os.ReadFile(internal.EntropyFilePath(secretName))
	assert.NoError(t, err)
	return content
}

func (tb *Testbed) ReadSecret(t *testing.T, identities []age.Identity, secretName string) string {
	allIdentities := make([]age.Identity, 0, len(identities)+len(tb.GeneratorIdentities))
	allIdentities = append(allIdentities, identities...)

	for _, identity := range tb.GeneratorIdentities {
		allIdentities = append(allIdentities, identity)
	}

	var lastRead *string
	for _, identity := range identities {
		secret := tb.readSecret(t, identity, secretName)
		if lastRead == nil {
			lastRead = &secret
		}
		assert.Equal(t, *lastRead, secret, "secret reads the same for all recipients")
	}

	return *lastRead
}

func (tb *Testbed) RunGenerator(t *testing.T, config internal.Config) {
	assert.NoError(t, generate.Run(context.Background(), IdentityFileName, config))
}

func (tb *Testbed) ReadSecretFile(t *testing.T, secretName string) []byte {
	content, err := os.ReadFile(internal.SecretFilePath(secretName))
	assert.NoError(t, err)
	return content
}

func (tb *Testbed) readSecret(t *testing.T, identity age.Identity, secretName string) string {
	secretFilePath := internal.SecretFilePath(secretName)

	secretFile, err := os.Open(secretFilePath)
	require.NoError(t, err)

	secretReader, err := age.Decrypt(secretFile, identity)
	require.NoError(t, err)

	secret, err := io.ReadAll(secretReader)
	require.NoError(t, err)

	require.NoError(t, secretFile.Close())

	return string(secret)
}

func (tb *Testbed) WriteSecret(t *testing.T, recipients []age.Recipient, secretName, content string) {
	allRecipients := make([]age.Recipient, 0, len(recipients)+len(tb.GeneratorIdentities))
	allRecipients = append(allRecipients, recipients...)

	for _, id := range tb.GeneratorIdentities {
		allRecipients = append(allRecipients, id.Recipient())
	}

	secretFilePath := internal.SecretFilePath(secretName)

	require.NoError(t, os.MkdirAll(filepath.Dir(secretFilePath), 0770))

	secretFile, err := os.Create(secretFilePath)
	require.NoError(t, err)

	secretWriter, err := age.Encrypt(secretFile, allRecipients...)
	require.NoError(t, err)

	_, err = io.WriteString(secretWriter, content)
	require.NoError(t, err)

	require.NoError(t, secretWriter.Close())
	require.NoError(t, secretFile.Close())
}

func InitializeTest(t *testing.T) *Testbed {
	cwd, err := os.Getwd()
	require.NoError(t, err)

	t.Cleanup(func() {
		_ = os.Chdir(cwd)
	})

	wd := t.TempDir()
	require.NoError(t, os.Chdir(wd))

	secretsDataDir := filepath.Join(internal.SecretsDirectory, internal.SecretsDataDirectory)
	require.NoError(t, os.MkdirAll(secretsDataDir, 0770))

	secretsEntropyDir := filepath.Join(internal.SecretsDirectory, internal.SecretsEntropyDirectory)
	require.NoError(t, os.MkdirAll(secretsEntropyDir, 0770))

	testbed := initializeTestbed(t)

	testbed.WorkingDir = wd

	identityFile, err := os.Create(IdentityFileName)
	require.NoError(t, err)

	for _, id := range testbed.GeneratorIdentities {
		_, err := io.WriteString(identityFile, id.String()+"\n")
		require.NoError(t, err)
	}

	require.NoError(t, identityFile.Close())

	return testbed
}

func initializeTestbed(t *testing.T) *Testbed {
	testbed := &Testbed{
		Identities: make(map[string][]age.Identity, len(Hosts)),
		PublicKeys: make(map[string][]string, len(Hosts)),
		Recipients: make(map[string][]age.Recipient, len(Hosts)),

		generatedSecretNames: make(map[string]bool),
	}

	for _, hostname := range Hosts {
		n := rand.Intn(2) + 1
		identities := make([]age.Identity, n)
		publicKeys := make([]string, n)
		recipients := make([]age.Recipient, n)

		for i := 0; i < n; i++ {
			identity, err := age.GenerateX25519Identity()
			require.NoError(t, err)

			identities[i] = identity
			publicKeys[i] = identity.Recipient().String()
			recipients[i] = identity.Recipient()
		}

		testbed.Identities[hostname] = identities
		testbed.PublicKeys[hostname] = publicKeys
		testbed.Recipients[hostname] = recipients
	}

	{
		n := rand.Intn(2) + 1
		for i := 0; i < n; i++ {
			id, err := age.GenerateX25519Identity()
			require.NoError(t, err)

			testbed.GeneratorIdentities = append(testbed.GeneratorIdentities, id)
		}
	}

	return testbed
}

func RandomMounts(mountsPerSecret map[string]int) map[string]internal.SecretMount {
	mounts := make(map[string]internal.SecretMount, len(mountsPerSecret))

	for secretName, n := range mountsPerSecret {
		for i := 0; i < n; i++ {
			mountName := fmt.Sprintf("%s/%d", secretName, i)

			mount := internal.SecretMount{
				Host:   Hosts[rand.Intn(len(Hosts))],
				Secret: secretName,
			}

			mounts[mountName] = mount
		}
	}

	return mounts
}

func RandomCharsets() map[string]bool {
	for {
		charsets := map[string]bool{}
		for name := range random.SupportedCharsets {
			if rand.Intn(2) == 1 {
				charsets[name] = true
			}
		}
		if len(charsets) > 0 {
			return charsets
		}
	}
}
