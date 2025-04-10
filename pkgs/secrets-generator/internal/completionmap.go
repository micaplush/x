package internal

import (
	"context"
)

var closed <-chan struct{}

type CompletionMap struct {
	completion map[string]context.Context
	cancel     map[string]context.CancelFunc
}

func (cm *CompletionMap) MarkComplete(secretName string) {
	cm.cancel[secretName]()
}

func (cm *CompletionMap) Done(secretName string) <-chan struct{} {
	completion, found := cm.completion[secretName]
	if !found {
		return closed
	}

	return completion.Done()
}

func init() {
	c := make(chan struct{})
	close(c)
	closed = c
}

func NewCompletionMap(secrets map[string]Secret) *CompletionMap {
	cm := &CompletionMap{
		completion: make(map[string]context.Context, len(secrets)),
		cancel:     make(map[string]context.CancelFunc, len(secrets)),
	}

	for name := range secrets {
		cm.completion[name], cm.cancel[name] = context.WithCancel(context.Background())
	}

	return cm
}
