package util

import (
	"net/http"
)

func ReadCookie(headerValues []string, name string) (*http.Cookie, error) {
	var httpReq http.Request
	httpReq.Header = make(http.Header)
	for _, c := range headerValues {
		httpReq.Header.Add("Cookie", c)
	}
	cookie, err := httpReq.Cookie(name)
	if err != nil {
		return nil, err
	}
	return cookie, nil
}
