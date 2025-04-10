package json

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"reflect"
	"slices"

	"tbx.at/secrets-generator/internal"
	"tbx.at/secrets-generator/internal/rand/argon2id"
	"tbx.at/secrets-generator/internal/rand/bcrypt"
)

const (
	functionNameFmt          = "fmt"
	functionNameHashArgon2id = "hashArgon2id"
	functionNameHashBcrypt   = "hashBcrypt"
	functionNameReadSecret   = "readSecret"
)

var (
	ErrArgumentMissing      = errors.New("function argument is missing")
	ErrArgumentsNotInMap    = errors.New("function arguments are not in a map")
	ErrFunctionDoesNotExist = errors.New("function does not exist")
	ErrGenerationCancelled  = errors.New("generation cancelled")
	ErrMissingArguments     = errors.New("function call is missing arguments")
	ErrMissingName          = errors.New("function call is missing a name")
	ErrNameNotAString       = errors.New("function name is not a string")
)

type GeneratorJSON struct {
	Completion  *internal.CompletionMap
	SecretStore *internal.SecretStore
}

func (gen *GeneratorJSON) Deterministic() bool {
	return true
}

func (gen *GeneratorJSON) Generate(ctx context.Context, rng io.Reader, secret internal.Secret, output io.Writer) error {
	content, err := gen.walkJSON(ctx, rng, secret.Generation.JSON.Content)
	if err != nil {
		return err
	}

	return json.NewEncoder(output).Encode(content)
}

func (gen *GeneratorJSON) walkJSON(ctx context.Context, rng io.Reader, value any) (walked any, err error) {
	switch cast := value.(type) {
	case map[string]any:
		if cast["__secretsGeneratorType"] == "functionCall" {
			return gen.processFunctionCall(ctx, rng, cast)
		}
		return gen.processObject(ctx, rng, cast)
	case []any:
		walked := make([]any, len(cast))
		for i, v := range cast {
			walked[i], err = gen.walkJSON(ctx, rng, v)
			if err != nil {
				return nil, err
			}
		}
		return walked, nil
	default:
		return cast, nil
	}
}

func (gen *GeneratorJSON) processObject(ctx context.Context, rng io.Reader, object map[string]any) (walked any, err error) {
	sortedKeys := make([]string, 0, len(object))
	for key := range object {
		sortedKeys = append(sortedKeys, key)
	}
	slices.Sort(sortedKeys)

	walkedObject := make(map[string]any, len(object))

	for _, key := range sortedKeys {
		value := object[key]

		walkedObject[key], err = gen.walkJSON(ctx, rng, value)
		if err != nil {
			return nil, err
		}
	}

	return walkedObject, nil
}

func (gen *GeneratorJSON) processFunctionCall(ctx context.Context, rng io.Reader, call map[string]any) (walked any, err error) {
	nameRaw, ok := call["name"]
	if !ok {
		return nil, ErrMissingName
	}

	name, ok := nameRaw.(string)
	if !ok {
		return nil, ErrNameNotAString
	}

	argsRaw, ok := call["arguments"]
	if !ok {
		return nil, ErrMissingArguments
	}

	argsWalked, err := gen.walkJSON(ctx, rng, argsRaw)
	if err != nil {
		return nil, err
	}

	argsMap, ok := argsWalked.(map[string]any)
	if !ok {
		return nil, ErrArgumentsNotInMap
	}

	fctx := functionCtx{
		Context: ctx,
		name:    name,
		rng:     rng,
		args:    argsMap,
	}

	switch name {
	case functionNameFmt:
		return gen.functionFmt(fctx)
	case functionNameHashArgon2id:
		return gen.functionHashArgon2id(fctx)
	case functionNameHashBcrypt:
		return gen.functionHashBcrypt(fctx)
	case functionNameReadSecret:
		return gen.functionReadSecret(fctx)
	default:
		return nil, ErrFunctionDoesNotExist
	}
}

type functionCtx struct {
	context.Context
	name string
	rng  io.Reader
	args map[string]any
}

func (gen *GeneratorJSON) functionFmt(ctx functionCtx) (walked any, err error) {
	format, err := getString(ctx, "format")
	if err != nil {
		return nil, err
	}

	argsRaw, err := getSlice(ctx, "args")
	if err != nil {
		return nil, err
	}

	argsWalked, err := gen.walkJSON(ctx, ctx.rng, argsRaw)
	if err != nil {
		return nil, err
	}

	args := argsWalked.([]any)

	return fmt.Sprintf(format, args...), nil
}

func (gen *GeneratorJSON) functionHashArgon2id(ctx functionCtx) (walked any, err error) {
	data, err := getAny(ctx, "data")
	if err != nil {
		return nil, err
	}

	var str string

	switch data := data.(type) {
	case []byte:
		str = string(data)
	case string:
		str = data
	default:
		str = fmt.Sprint(data)
	}

	memory, err := getNumber(ctx, "memory")
	if err != nil {
		return nil, err
	}

	iterations, err := getNumber(ctx, "iterations")
	if err != nil {
		return nil, err
	}

	parallelism, err := getNumber(ctx, "parallelism")
	if err != nil {
		return nil, err
	}

	return argon2id.CreateHash(ctx.rng, str, &argon2id.Params{
		Memory:      uint32(memory),
		Iterations:  uint32(iterations),
		Parallelism: uint8(parallelism),
		SaltLength:  16,
		KeyLength:   32,
	})
}

func (gen *GeneratorJSON) functionHashBcrypt(ctx functionCtx) (walked any, err error) {
	data, err := getAny(ctx, "data")
	if err != nil {
		return nil, err
	}

	var bytes []byte

	switch data := data.(type) {
	case []byte:
		bytes = data
	case string:
		bytes = []byte(data)
	default:
		bytes = []byte(fmt.Sprint(data))
	}

	rounds, err := getNumber(ctx, "rounds")
	if err != nil {
		return nil, err
	}

	hash, err := bcrypt.GenerateFromPassword(ctx.rng, bytes, int(rounds))
	if err != nil {
		return nil, err
	}

	return string(hash), nil
}

func (gen *GeneratorJSON) functionReadSecret(ctx functionCtx) (walked any, err error) {
	name, err := getString(ctx, "name")
	if err != nil {
		return nil, err
	}

	select {
	case <-gen.Completion.Done(name):
	case <-ctx.Done():
		return nil, ErrGenerationCancelled
	}

	return gen.SecretStore.LoadSecret(name)
}

func getNumber(ctx functionCtx, name string) (float64, error) {
	argRaw, ok := ctx.args[name]
	if !ok {
		return 0, fmt.Errorf("%w in call to %s: %s", ErrArgumentMissing, ctx.name, name)
	}

	arg, ok := argRaw.(float64)
	if !ok {
		return 0, fmt.Errorf("argument %s has wrong type in call to %s: wanted float64, got %s", name, ctx.name, reflect.TypeOf(argRaw).Name())
	}

	return arg, nil
}

func getString(ctx functionCtx, name string) (string, error) {
	argRaw, ok := ctx.args[name]
	if !ok {
		return "", fmt.Errorf("%w in call to %s: %s", ErrArgumentMissing, ctx.name, name)
	}

	arg, ok := argRaw.(string)
	if !ok {
		return "", fmt.Errorf("argument %s has wrong type in call to %s: wanted string, got %s", name, ctx.name, reflect.TypeOf(argRaw).Name())
	}

	return arg, nil
}

func getSlice(ctx functionCtx, name string) ([]any, error) {
	argRaw, ok := ctx.args[name]
	if !ok {
		return nil, fmt.Errorf("%w in call to %s: %s", ErrArgumentMissing, ctx.name, name)
	}

	arg, ok := argRaw.([]any)
	if !ok {
		return nil, fmt.Errorf("argument %s has wrong type in call to %s: wanted []any, got %s", name, ctx.name, reflect.TypeOf(argRaw).Name())
	}

	return arg, nil
}

func getAny(ctx functionCtx, name string) (any, error) {
	arg, ok := ctx.args[name]
	if !ok {
		return nil, fmt.Errorf("%w in call to %s: %s", ErrArgumentMissing, ctx.name, name)
	}

	return arg, nil
}
