package model

type TODOListID string
type ListItemID string

type TODOList struct {
	ID    TODOListID
	Owner UserID
	Items []*ListItem
}

type ListItem struct {
	ID   ListItemID
	Text string
}

type UserID string
type User struct {
	ID             UserID
	Name           string
	YandexAvatarID string
}

type AccessMode string

func (m AccessMode) Grantable() bool {
	return m == AccessModeRead || m == AccessModeReadWrite
}

func (m AccessMode) CanRead() bool {
	return m.CanWrite() || m == AccessModeRead
}

func (m AccessMode) CanWrite() bool {
	return m.CanInvite() || m == AccessModeReadWrite
}
func (m AccessMode) CanInvite() bool {
	return m == AccessModeOwner
}

const (
	AccessModeRead      AccessMode = "R"
	AccessModeReadWrite AccessMode = "RW"
	AccessModeOwner     AccessMode = "O"
)

type ACLEntry struct {
	User     UserID
	Mode     AccessMode
	ListID   TODOListID
	Alias    string
	Inviter  UserID
	Accepted bool
}
