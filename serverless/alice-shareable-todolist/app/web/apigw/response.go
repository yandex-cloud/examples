package apigw

import (
	"bytes"
	"encoding/base64"
	"net/http"
)

type Response struct {
	StatusCode      int                 `json:"statusCode"`
	Body            string              `json:"body"`
	Headers         map[string][]string `json:"headers"`
	IsBase64Encoded bool                `json:"isBase64Encoded"`
}

var _ http.ResponseWriter = &ResponseWriter{}

type ResponseWriter struct {
	headers http.Header
	body    bytes.Buffer
	status  int
}

func NewResponseWriter() *ResponseWriter {
	res := &ResponseWriter{
		headers: make(http.Header),
	}
	res.body.Reset()
	return res
}

func (rw *ResponseWriter) Header() http.Header {
	return rw.headers
}

func (rw *ResponseWriter) Write(bytes []byte) (int, error) {
	return rw.body.Write(bytes)
}

func (rw *ResponseWriter) WriteHeader(statusCode int) {
	rw.status = statusCode
}

func (rw *ResponseWriter) ToResponse() *Response {
	res := &Response{
		StatusCode: rw.status,
		Headers:    rw.headers,
	}
	if res.StatusCode == 0 {
		res.StatusCode = http.StatusOK
	}
	if rw.body.Len() > 0 {
		res.IsBase64Encoded = true
		res.Body = base64.StdEncoding.EncodeToString(rw.body.Bytes())
	}
	return res
}
