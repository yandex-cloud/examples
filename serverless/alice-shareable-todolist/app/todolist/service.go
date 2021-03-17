package todolist

import (
	"context"

	"github.com/yandex-cloud/examples/serverless/alice-shareable-todolist/app/db"
	"github.com/yandex-cloud/examples/serverless/alice-shareable-todolist/app/errors"
	"github.com/yandex-cloud/examples/serverless/alice-shareable-todolist/app/model"
)

const (
	maxListsPerUser = 10
	maxItemsPerList = 20
)

type Service interface {
	Create(ctx context.Context, req *ListCreateRequest) (model.TODOListID, errors.Err)
	Get(ctx context.Context, req *ListGetRequest) (*model.TODOList, *model.ACLEntry, errors.Err)
	AddItem(ctx context.Context, req *ItemAddRequest) errors.Err
	RemoveItem(ctx context.Context, req *ItemRemoveRequest) errors.Err

	GetUserLists(ctx context.Context, req *GetUserListsRequest) ([]*model.ACLEntry, errors.Err)
	GetListUsers(ctx context.Context, req *GetListACLRequest) ([]*model.ACLEntry, errors.Err)

	InviteUser(ctx context.Context, req *InviteRequest) errors.Err
	AcceptAndRenameList(ctx context.Context, req *AcceptAndRenameListRequest) errors.Err
	RemoveList(ctx context.Context, req *RemoveListRequest) errors.Err
	RevokeInvitation(ctx context.Context, req *InvitationRevokeRequest) errors.Err
}

type ListCreateRequest struct {
	Name string
}

type ListRenameRequest struct {
	ListID model.TODOListID
	Name   string
}

type ListRemoveRequest struct {
	ID model.TODOListID
}

type GetUserListsRequest struct {
}

type GetListACLRequest struct {
	ID model.TODOListID
}

type GetListRequest struct {
	ID model.TODOListID
}

type ListGetRequest struct {
	ID model.TODOListID
}

type ItemAddMode string

const (
	ItemPrepend ItemAddMode = "PREPEND"
	ItemAppend  ItemAddMode = "APPEND"
)

type ItemAddRequest struct {
	ListID model.TODOListID
	Text   string
	Mode   ItemAddMode
}

type ItemRemoveRequest struct {
	ListID model.TODOListID
	ItemID model.ListItemID
}

type InviteRequest struct {
	ListID  model.TODOListID
	Invitee model.UserID
	Access  model.AccessMode
}

type AcceptAndRenameListRequest struct {
	ListID model.TODOListID
	Alias  string
}

type RemoveListRequest struct {
	ID model.TODOListID
}

type InvitationRevokeRequest struct {
	ListID  model.TODOListID
	Invitee model.UserID
}

var _ Service = &service{}

type service struct {
	repo  db.Repository
	txMgr db.TxManager
}

func NewService(deps Deps) (Service, error) {
	return &service{
		repo:  deps.GetRepository(),
		txMgr: deps.GetTxManager(),
	}, nil
}
