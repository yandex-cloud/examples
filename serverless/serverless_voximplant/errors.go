package main

import (
	"fmt"
)

func newErrorBadRequest(msg string) error {
	return &userError{
		msg:    msg,
		status: 400,
	}
}

func newErrorUnauthorized(msg string) error {
	return &userError{
		msg:    msg,
		status: 401,
	}
}

var _ error = &userError{}

type userError struct {
	msg    string
	status int
}

func (e *userError) Error() string {
	return fmt.Sprintf("%d: %s", e.status, e.msg)
}
