// Code generated by go-swagger; DO NOT EDIT.

package operations

// This file was generated by the swagger tool.
// Editing this file might prove futile when you re-run the generate command

import (
	"errors"
	"net/url"
	golangswaggerpaths "path"
	"strings"
)

// RevokeInvitationURL generates an URL for the revoke invitation operation
type RevokeInvitationURL struct {
	ListID string
	UserID string

	_basePath string
	// avoid unkeyed usage
	_ struct{}
}

// WithBasePath sets the base path for this url builder, only required when it's different from the
// base path specified in the swagger spec.
// When the value of the base path is an empty string
func (o *RevokeInvitationURL) WithBasePath(bp string) *RevokeInvitationURL {
	o.SetBasePath(bp)
	return o
}

// SetBasePath sets the base path for this url builder, only required when it's different from the
// base path specified in the swagger spec.
// When the value of the base path is an empty string
func (o *RevokeInvitationURL) SetBasePath(bp string) {
	o._basePath = bp
}

// Build a url path and query string
func (o *RevokeInvitationURL) Build() (*url.URL, error) {
	var _result url.URL

	var _path = "/api/todo-lists/{list_id}/users/{user_id}/wa"

	listID := o.ListID
	if listID != "" {
		_path = strings.Replace(_path, "{list_id}", listID, -1)
	} else {
		return nil, errors.New("listId is required on RevokeInvitationURL")
	}

	userID := o.UserID
	if userID != "" {
		_path = strings.Replace(_path, "{user_id}", userID, -1)
	} else {
		return nil, errors.New("userId is required on RevokeInvitationURL")
	}

	_basePath := o._basePath
	_result.Path = golangswaggerpaths.Join(_basePath, _path)

	return &_result, nil
}

// Must is a helper function to panic when the url builder returns an error
func (o *RevokeInvitationURL) Must(u *url.URL, err error) *url.URL {
	if err != nil {
		panic(err)
	}
	if u == nil {
		panic("url can't be nil")
	}
	return u
}

// String returns the string representation of the path with query string
func (o *RevokeInvitationURL) String() string {
	return o.Must(o.Build()).String()
}

// BuildFull builds a full url with scheme, host, path and query string
func (o *RevokeInvitationURL) BuildFull(scheme, host string) (*url.URL, error) {
	if scheme == "" {
		return nil, errors.New("scheme is required for a full url on RevokeInvitationURL")
	}
	if host == "" {
		return nil, errors.New("host is required for a full url on RevokeInvitationURL")
	}

	base, err := o.Build()
	if err != nil {
		return nil, err
	}

	base.Scheme = scheme
	base.Host = host
	return base, nil
}

// StringFull returns the string representation of a complete url
func (o *RevokeInvitationURL) StringFull(scheme, host string) string {
	return o.Must(o.BuildFull(scheme, host)).String()
}