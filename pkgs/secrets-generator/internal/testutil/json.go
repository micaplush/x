package testutil

func JSONFunctionCall(name string, arguments map[string]any) map[string]any {
	return map[string]any{
		"__secretsGeneratorType": "functionCall",
		"name":                   name,
		"arguments":              arguments,
	}
}
