package util

import (
	"testing"

	"github.com/stretchr/testify/require"
)

func TestReadCookie(t *testing.T) {
	c, err := ReadCookie([]string{"session_id=abcdefg"}, "session_id")
	require.NoError(t, err)
	require.Equal(t, "abcdefg", c.Value)
}
