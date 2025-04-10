package main

import (
	"bytes"
	"context"
	"errors"
	"fmt"
	"io"
	"log/slog"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"time"

	"github.com/emersion/go-imap"
	"github.com/emersion/go-imap/client"
	imapclient "github.com/emersion/go-imap/client"
	_ "github.com/emersion/go-message/charset"
	"github.com/emersion/go-message/mail"
)

type application struct {
	// parameters

	consumeDir   string
	delete       bool
	passwordFile string
	server       string
	username     string

	// runtime stuff

	client *imapclient.Client
	logger *slog.Logger
}

func (a *application) initialize() (err error) {
	for attempts := 1; ; attempts++ {
		a.client, err = client.DialTLS(a.server, nil)

		if err == nil {
			break
		} else if attempts >= 30 {
			a.logger.Error("exceeded maximum number of retries connecting to IMAP server")
			return err
		}

		a.logger.Debug(
			"error connecting to IMAP server, retying",
			slog.String("error", err.Error()),
			slog.Int("attempts", attempts),
		)

		time.Sleep(500 * time.Millisecond)
	}

	a.logger.Info("connected to the IMAP server")

	var password string
	{
		b, err := os.ReadFile(a.passwordFile)
		if err != nil {
			_ = a.client.Logout()
			return fmt.Errorf("error reading password from file: %w", err)
		}
		password = string(bytes.TrimSpace(b))
	}

	if err := a.client.Login(a.username, password); err != nil {
		return err
	}

	a.logger.Info("authenticated to the IMAP server")

	return nil
}

func (a *application) stop() (err error) {
	if a.client != nil {
		c := a.client
		a.client = nil
		return c.Logout()
	}

	return nil
}

func (a *application) runMainLoop(ctx context.Context) error {
	for {
		messages, err := a.waitForMessages(ctx)
		if err != nil {
			return fmt.Errorf("error waiting for messages: %w", err)
		}

		if messages > 0 {
			if err := a.processMessages(); err != nil {
				return fmt.Errorf("error processing messages in inbox: %w", err)
			}
		}

		if err := ctx.Err(); err != nil {
			return err
		}
	}
}

func (a *application) waitForMessages(ctx context.Context) (messages uint, err error) {
	updateCh := make(chan client.Update)
	defer close(updateCh)

	status, err := a.client.Select("INBOX", false)
	if err != nil {
		return 0, err
	}
	a.logger.Info("selected mailbox")

	if status.Messages > 0 {
		a.logger.Debug("got messages from select", slog.Uint64("messages", uint64(status.Messages)))
		return uint(status.Messages), nil
	}

	a.client.Updates = updateCh
	errCh := make(chan error, 1)

	ctx, cancelIdle := context.WithCancel(ctx)

	// This defer is technically not needed since the only way to exit without calling defer is in the case where we receive something on errCh below.
	// And the only value written to errCh is the return value from the idle call, so by that point, idle is done anyways.
	// But having this defer makes a warning in VS Code go away and it might help in case this function changes in the future.
	defer cancelIdle()

	a.logger.Info("starting idle")
	go func() {
		errCh <- a.client.Idle(ctx.Done(), nil)
	}()

UPDATES:
	for {
		select {
		case update := <-updateCh:
			switch update := update.(type) {
			case *client.MailboxUpdate:
				if update.Mailbox.Messages > 0 {
					messages = uint(update.Mailbox.Messages)
					cancelIdle()
				}
			default:
			}
		case err := <-errCh:
			a.client.Updates = nil

			// drain the update channel
		DRAIN:
			for {
				select {
				case <-updateCh:
				default:
					break DRAIN
				}
			}

			if err != nil {
				return 0, err
			}

			break UPDATES
		}
	}

	return messages, nil
}

func (a *application) processMessages() error {
	emptyCriteria := imap.NewSearchCriteria()

	uids, err := a.client.UidSearch(emptyCriteria)
	if err != nil {
		return err
	}

	seqSet := new(imap.SeqSet)
	seqSet.AddNum(uids...)

	messages := make(chan *imap.Message, 10) // closed automatically

	errCh := make(chan error, 1)
	defer close(errCh)

	go func() {
		errCh <- a.client.UidFetch(seqSet, []imap.FetchItem{
			imap.FetchEnvelope,
			imap.FetchItem("BODY.PEEK[]"),
		}, messages)
	}()

	deleteSeqSet := new(imap.SeqSet)
	var processingErr error

	for msg := range messages {
		if processingErr != nil {
			continue
		}

		processingErr = a.processMessage(msg)
		if processingErr == nil {
			deleteSeqSet.AddNum(msg.Uid)
		}
	}

	var hadErrors bool

	if processingErr != nil {
		hadErrors = true
		a.logger.Error("error during processing of received messages", slog.String("error", processingErr.Error()))
	}

	if err := <-errCh; err != nil {
		hadErrors = true
		a.logger.Error("error from IMAP fetch operation", slog.String("error", err.Error()))
	}

	if a.delete && !deleteSeqSet.Empty() {
		item := imap.FormatFlagsOp(imap.AddFlags, true)
		flags := []interface{}{imap.DeletedFlag}

		if err := a.client.UidStore(deleteSeqSet, item, flags, nil); err != nil {
			hadErrors = true
			a.logger.Error("error setting delete flag on processed messages", slog.String("error", err.Error()))
		}

		if err := a.client.Expunge(nil); err != nil {
			hadErrors = true
			a.logger.Error("error expunging processed messages", slog.String("error", err.Error()))
		}
	}

	if hadErrors {
		return errors.New("errors while fetching or processing messages (see log)")
	}

	return nil
}

func (a *application) processMessage(msg *imap.Message) error {
	idAttr := slog.String("message-id", msg.Envelope.MessageId)

	a.logger.Info(
		"processing message",
		idAttr,
		slog.String("subject", msg.Envelope.Subject),
		slog.Time("date", msg.Envelope.Date),
	)

	switch len(msg.Envelope.To) {
	case 0:
		err := errors.New("message without receiver in envelope")
		a.logger.Error(err.Error(), idAttr)
		return err
	case 1:
	default:
		a.logger.Warn(
			"more than one reciever in envelope, ignoring all but first",
			idAttr,
			slog.Any("receivers", msg.Envelope.To),
		)
	}

	receiver := msg.Envelope.To[0]
	a.logger.Info("receiver address", idAttr, slog.String("to", receiver.Address()))

	_, tag, _ := strings.Cut(receiver.MailboxName, "+")
	if tag != "" {
		a.logger.Info("has tag", idAttr, slog.String("tag", tag))
	}

	var i int
	for _, bodyLiteral := range msg.Body {
		if err := a.processBody(idAttr, strconv.Itoa(i), tag, bodyLiteral); err != nil {
			return err
		}
		i++
	}

	return nil
}

func (a *application) processBody(msgIDAttr slog.Attr, partIndexPath string, tag string, body io.Reader) error {
	r, err := mail.CreateReader(body)
	if err != nil {
		return err
	}
	defer r.Close()

	for i := 0; ; i++ {
		p, err := r.NextPart()
		if err != nil {
			if errors.Is(err, io.EOF) {
				break
			}
			return err
		}

		partIndexPath := fmt.Sprint(partIndexPath, ".", i)
		indexPathAttr := slog.String("indexpath", partIndexPath)
		a.logger.Debug("processing part", msgIDAttr, indexPathAttr)

		var discard bool

		switch header := p.Header.(type) {
		case *mail.AttachmentHeader:
			if err := a.processAttachment(p, header, tag); err != nil {
				return err
			}
		case *mail.InlineHeader:
			contentType, _, err := header.ContentType()
			if err != nil {
				return err
			}
			a.logger.Debug("part content type", msgIDAttr, indexPathAttr, slog.String("content-type", contentType))

			if contentType == "message/rfc822" {
				if err := a.processBody(msgIDAttr, partIndexPath, tag, p.Body); err != nil {
					return err
				}
			} else {
				discard = true
			}
		default:
			discard = true
		}

		if discard {
			a.logger.Debug("discarding part", msgIDAttr, indexPathAttr)
			if _, err = io.Copy(io.Discard, p.Body); err != nil {
				return err
			}
		}
	}

	return nil
}

func (a *application) processAttachment(part *mail.Part, header *mail.AttachmentHeader, tag string) error {
	contentType, _, err := header.ContentType()
	if err != nil {
		return err
	}

	if contentType != "application/pdf" {
		a.logger.Info("skipping non-PDF attachment", slog.String("content-type", contentType))
		return nil
	}

	filename, err := header.Filename()
	if err != nil {
		return err
	}

	a.logger.Info("processing attachment", slog.String("filename", filename))

	dir := a.consumeDir
	if tag != "" {
		dir = filepath.Join(dir, tag)
	}

	a.logger.Debug("creating directory", slog.String("dir", dir))

	if err := os.MkdirAll(dir, 0770); err != nil {
		return err
	}

	path := filepath.Join(dir, filename)
	a.logger.Debug("creating file", slog.String("path", path))

	file, err := os.Create(path)
	if err != nil {
		return err
	}
	defer file.Close()

	a.logger.Debug("copying data", slog.String("path", path))

	_, err = io.Copy(file, part.Body)
	return err
}
