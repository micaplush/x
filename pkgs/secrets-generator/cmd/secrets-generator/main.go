package main

import (
	"context"
	"encoding/json"
	"flag"
	"os"
	"os/signal"
	"syscall"

	"tbx.at/secrets-generator/internal"
	"tbx.at/secrets-generator/internal/generate"
)

func main() {
	var configPath string
	var identityPath string

	flag.StringVar(&configPath, "config", "-", "file containing the configuration")
	flag.StringVar(&identityPath, "identity", "", "file containing an age identity that can decrypt all secrets")

	flag.Parse()

	configFile := os.Stdin
	if configPath != "-" {
		f, err := os.Open(configPath)
		if err != nil {
			panic(err)
		}
		defer f.Close()
		configFile = f
	}

	var config internal.Config
	if err := json.NewDecoder(configFile).Decode(&config); err != nil {
		panic(err)
	}

	ctx, _ := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)

	if err := generate.Run(ctx, identityPath, config); err != nil {
		panic(err)
	}
}
