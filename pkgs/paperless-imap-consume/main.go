package main

import (
	"context"
	"errors"
	"flag"
	"fmt"
	"log/slog"
	"os"
	"os/signal"
)

func main() {
	app := &application{}

	var logLevelStr string

	flag.StringVar(&app.server, "server", "", "IMAPS server to connect to")
	flag.StringVar(&app.username, "username", "", "username for authentication")
	flag.StringVar(&app.passwordFile, "password-file", "", "file containing the password for authentication")
	flag.StringVar(&app.consumeDir, "consume-dir", "", "directory to place downloaded attachments in")
	flag.BoolVar(&app.delete, "delete", false, "delete messages after processing")
	flag.StringVar(&logLevelStr, "log-level", "info", "level of detail for log output (debug, info, warn, error)")
	flag.Parse()

	var logLevel slog.Level
	if err := logLevel.UnmarshalText([]byte(logLevelStr)); err != nil {
		panic(fmt.Errorf("error parsing log level: %w", err))
	}

	app.logger = slog.New(slog.NewTextHandler(os.Stderr, &slog.HandlerOptions{
		Level: slog.LevelDebug,
	}))

	ctx, _ := signal.NotifyContext(context.Background(), os.Interrupt)

	if err := app.initialize(); err != nil {
		panic(err)
	}

	defer app.stop()

	if err := app.runMainLoop(ctx); err != nil && !errors.Is(err, context.Canceled) {
		panic(err)
	}

	if err := app.stop(); err != nil {
		panic(err)
	}
}
