package errors

import (
	"fmt"
)

type Code string

func (c Code) IsUser() bool {
	return c != CodeInternal && c != CodeUnavailable
}

const (
	CodeInternal        Code = "INTERNAL"
	CodeUnavailable     Code = "UNAVAILABLE"
	CodeUnauthenticated Code = "UNAUTHENTICATED"
	CodeUnauthorized    Code = "UNAUTHORIZED"
	CodeBadRequest      Code = "BAD_REQUEST"
	CodeNotFound        Code = "NOT_FOUND"
	CodeDuplicateName   Code = "DUPLICATE_NAME"
	CodeLimitExceeded   Code = "LIMIT_EXCEEDED"
)

func NewInternal(err error) Err {
	return newErr(CodeInternal, "Internal server error", err)
}

func NewUnavailable(err error) Err {
	return newErr(CodeUnavailable, "Service temporary unavailable", err)
}

func NewUnauthenticated() Err {
	return newErr(CodeUnauthenticated, "Authentication required", nil)
}

func NewUnauthorized(msg string) Err {
	return newErr(CodeUnauthorized, msg, nil)
}

func NewDuplicateName(name string) Err {
	return &DuplicateName{
		err:  *newErr(CodeDuplicateName, fmt.Sprintf("List with similar name '%s' aleady exist", name), nil),
		Name: name,
	}
}
func NewLimitExceeded(msg string) Err {
	return newErr(CodeLimitExceeded, fmt.Sprintf(msg), nil)
}

func NewNotFound(msg string) Err {
	return newErr(CodeNotFound, msg, nil)
}

func NewBadRequest(msg string) Err {
	return newErr(CodeBadRequest, msg, nil)
}

type Err interface {
	error
	GetCode() Code
	GetMessage() string
	Unwrap() error
}

type DuplicateName struct {
	err
	Name string
}

func newErr(code Code, msg string, cause error) *err {
	return &err{code: code, msg: msg, cause: cause}
}

type err struct {
	code  Code
	msg   string
	cause error
}

func (e *err) Unwrap() error {
	return e.cause
}

func (e *err) Error() string {
	return fmt.Sprintf("%s: %s", e.code, e.msg)
}

func (e *err) GetCode() Code {
	return e.code
}

func (e *err) GetMessage() string {
	return e.msg
}
