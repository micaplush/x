package main

import (
	"bytes"
	"context"
	"encoding/json"
	"flag"
	"fmt"
	"io"
	"net/http"
	"os"

	"golang.org/x/oauth2/clientcredentials"
)

type response struct {
	Key string `json:"key"`
}

func main() {
	var clientIDPath string
	var clientSecretPath string

	flag.StringVar(&clientIDPath, "client-id", "", "File containing the Tailscale API client ID")
	flag.StringVar(&clientSecretPath, "client-secret", "", "File containing the Tailscale API client secret")
	flag.Parse()

	clientID, err := os.ReadFile(clientIDPath)
	if err != nil {
		panic(err)
	}

	clientSecret, err := os.ReadFile(clientSecretPath)
	if err != nil {
		panic(err)
	}

	var oauthConfig = &clientcredentials.Config{
		ClientID:     string(bytes.TrimSpace(clientID)),
		ClientSecret: string(bytes.TrimSpace(clientSecret)),
		TokenURL:     "https://api.tailscale.com/api/v2/oauth/token",
	}

	client := oauthConfig.Client(context.Background())
	defer client.CloseIdleConnections()

	payload := map[string]any{
		"capabilities": map[string]any{
			"devices": map[string]any{
				"create": map[string]any{
					"reusable":      false,
					"ephemeral":     false,
					"preauthorized": true,
					"tags": []string{
						"tag:server",
					},
				},
			},
		},
	}

	payloadBytes, err := json.Marshal(payload)
	if err != nil {
		panic(err)
	}

	resp, err := client.Post(
		"https://api.tailscale.com/api/v2/tailnet/t0astbread.github/keys",
		"application/json",
		bytes.NewReader(payloadBytes),
	)
	if err != nil {
		panic(err)
	}

	if resp.StatusCode != http.StatusOK {
		body, err := io.ReadAll(resp.Body)
		if err != nil {
			panic(err)
		}

		fmt.Printf("response: %s", string(body))

		panic(fmt.Errorf("non-200 status: %s", resp.Status))
	}

	var response response
	if err := json.NewDecoder(resp.Body).Decode(&response); err != nil {
		panic(err)
	}

	fmt.Println(response.Key)
}
