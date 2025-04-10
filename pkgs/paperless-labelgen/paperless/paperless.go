package paperless

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"os"
	"strconv"
	"time"
)

type Document struct {
	ASN      uint `json:"archive_serial_number"`
	Added    time.Time
	AddedStr string   `json:"added"`
	ID       uint     `json:"id"`
	Tags     []string `json:"tags"`
}

type Client struct {
	url, username, password string
}

func NewClient(url, username, passwordFile string) (*Client, error) {
	pw, err := os.ReadFile(passwordFile)
	if err != nil {
		return nil, err
	}

	return &Client{
		url:      url,
		username: username,
		password: string(pw),
	}, nil
}

func (c *Client) request(method, path string, body io.Reader) (*http.Response, error) {
	rqURL, err := url.JoinPath(c.url, "/api/", path, "/")
	if err != nil {
		return nil, err
	}

	rq, err := http.NewRequest(method, rqURL, body)
	if err != nil {
		return nil, err
	}

	rq.SetBasicAuth(c.username, c.password)

	if body != nil {
		rq.Header.Add("Content-Type", "application/json")
	}

	res, err := http.DefaultClient.Do(rq)
	if err != nil {
		return nil, err
	}

	if res.StatusCode != http.StatusOK {
		res.Body.Close()
		return nil, fmt.Errorf("unexpected status code: %d", res.StatusCode)
	}

	return res, nil
}

func (c *Client) GetDocument(id uint) (Document, error) {
	res, err := c.request(http.MethodGet, fmt.Sprintf("documents/%d", id), nil)
	if err != nil {
		return Document{}, err
	}

	defer res.Body.Close()

	var document Document
	if err := json.NewDecoder(res.Body).Decode(&document); err != nil {
		return Document{}, err
	}

	document.Added, err = time.Parse(time.RFC3339, document.AddedStr)
	if err != nil {
		return Document{}, err
	}

	return document, nil
}

func (c *Client) AssignNextASN(id uint) (asn uint, err error) {
	asn, err = c.getNextASN()
	if err != nil {
		return asn, err
	}

	body, err := json.Marshal(map[string]any{
		"archive_serial_number": asn,
	})

	if _, err := c.request(http.MethodPatch, fmt.Sprintf("documents/%d", id), bytes.NewReader(body)); err != nil {
		return asn, err
	}

	return asn, nil
}

func (c *Client) getNextASN() (asn uint, err error) {
	res, err := c.request(http.MethodGet, "documents/next_asn", nil)
	if err != nil {
		return asn, err
	}

	defer res.Body.Close()

	resBytes, err := io.ReadAll(res.Body)
	if err != nil {
		return asn, err
	}

	a, err := strconv.Atoi(string(resBytes))
	if err != nil {
		return asn, err
	}

	return uint(a), nil
}
