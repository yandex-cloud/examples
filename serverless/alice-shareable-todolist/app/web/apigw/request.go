package apigw

import (
	"bytes"
	"encoding/base64"
	"fmt"
	"io"
	"net/http"
	"net/url"

	"github.com/yandex-cloud/examples/serverless/alice-shareable-todolist/app/errors"
)

type Request struct {
	Method       string              `json:"httpMethod"`
	Path         string              `json:"path"`
	URL          string              `json:"url"`
	QueryParams  map[string][]string `json:"multiValueQueryStringParameters"`
	Headers      map[string][]string `json:"multiValueHeaders"`
	Body         string              `json:"body"`
	IsB64Encoded bool                `json:"isBase64Encoded"`
}

func (r *Request) RequireQueryParam(name string) (string, errors.Err) {
	value := r.QueryParamString(name)
	if value == "" {
		return "", errors.NewBadRequest(fmt.Sprintf("missing required parameter '%s'", name))
	}
	return value, nil
}

func (r *Request) QueryParamString(name string) string {
	values := r.QueryParams[name]
	if len(values) > 0 {
		return values[0]
	}
	return ""
}

func (r *Request) HeaderString(name string) string {
	values := r.Headers[name]
	if len(values) > 0 {
		return values[0]
	}
	return ""
}

func (r *Request) MakeHTTPRequest() (*http.Request, error) {
	var err error
	var res http.Request
	res.URL, err = url.Parse(r.URL)
	if err != nil {
		return nil, err
	}
	res.Method = r.Method
	res.Body, res.ContentLength, err = r.makeBody()
	if err != nil {
		return nil, fmt.Errorf("parsing request body: %w", err)
	}
	res.Header = r.Headers
	if h, ok := r.Headers["X-Forwarded-For"]; ok && len(h) > 0 {
		res.RemoteAddr = h[0] + ":0"
	}
	return &res, nil
}

func (r *Request) makeBody() (io.ReadCloser, int64, error) {
	bodyStr := r.Body
	var bodyBytes []byte
	if r.IsB64Encoded {
		var err error
		bodyBytes, err = base64.StdEncoding.DecodeString(bodyStr)
		if err != nil {
			return nil, 0, err
		}
	} else {
		bodyBytes = []byte(bodyStr)
	}
	return readCloser{bytes.NewReader([]byte(bodyBytes))}, int64(len(bodyBytes)), nil
}
