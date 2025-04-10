package internal

import "path/filepath"

const (
	SecretsDirectory = "secrets"

	SecretsDataDirectory    = "data"
	SecretsEntropyDirectory = "entropy"
)

type Config struct {
	PublicKeys   map[string][]string    `json:"publicKeys"`
	Secrets      map[string]Secret      `json:"secrets"`
	SecretMounts map[string]SecretMount `json:"secretMounts"`
}

type Secret struct {
	Generation GenerationParams `json:"generation"`
}

type GenerationParams struct {
	JSON     *GenerationParamsJSON     `json:"json"`
	Random   *GenerationParamsRandom   `json:"random"`
	Script   *GenerationParamsScript   `json:"script"`
	Template *GenerationParamsTemplate `json:"template"`
}

type GenerationParamsJSON struct {
	Content any `json:"content"`
}

type GenerationParamsRandom struct {
	Charsets map[string]bool `json:"charsets"`
	Length   int             `json:"length"`
}

type GenerationParamsScript struct {
	Program string `json:"program"`
}

type GenerationParamsTemplate struct {
	Data    map[string]any `json:"data"`
	Content string         `json:"content"`
}

type SecretMount struct {
	Host   string `json:"host"`
	Secret string `json:"secret"`
}

func EntropyFilePath(secretName string) string {
	return filepath.Join(SecretsDirectory, SecretsEntropyDirectory, secretName+".age")
}

func SecretFilePath(secretName string) string {
	return filepath.Join(SecretsDirectory, SecretsDataDirectory, secretName+".age")
}
