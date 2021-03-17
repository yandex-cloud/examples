package todolist

import (
	"context"
	"fmt"

	"github.com/yandex-cloud/examples/serverless/alice-shareable-todolist/app/auth"
	"github.com/yandex-cloud/examples/serverless/alice-shareable-todolist/app/db"
	"github.com/yandex-cloud/examples/serverless/alice-shareable-todolist/app/errors"
	"github.com/yandex-cloud/examples/serverless/alice-shareable-todolist/app/model"
	"github.com/yandex-cloud/examples/serverless/alice-shareable-todolist/app/util"
)

func (s *service) Create(ctx context.Context, req *ListCreateRequest) (model.TODOListID, errors.Err) {
	user, err := auth.UserFromCtxOrErr(ctx)
	if err != nil {
		return "", err
	}
	id := model.TODOListID(util.GenerateID())
	err = s.txMgr.InTx(ctx).Do(func(ctx context.Context) error {
		err := s.assureCanCreateList(ctx, user.ID, req.Name, "")
		if err != nil {
			return err
		}
		list := &model.TODOList{
			ID:    id,
			Owner: user.ID,
		}
		aclEntry := &model.ACLEntry{
			User:     user.ID,
			Mode:     model.AccessModeOwner,
			ListID:   list.ID,
			Alias:    req.Name,
			Accepted: true,
			Inviter:  user.ID,
		}
		err = s.repo.SaveTODOList(ctx, list)
		if err != nil {
			return err
		}
		return s.repo.SaveACLEntry(ctx, aclEntry)
	})
	if err != nil {
		return "", err
	}
	return id, nil
}

func (s *service) Get(ctx context.Context, req *ListGetRequest) (*model.TODOList, *model.ACLEntry, errors.Err) {
	user, err := auth.UserFromCtxOrErr(ctx)
	if err != nil {
		return nil, nil, err
	}
	var acl *model.ACLEntry
	var todoList *model.TODOList
	err = s.txMgr.InTx(ctx, db.TxRO()).Do(func(ctx context.Context) error {
		var err error
		acl, err = s.assureUserPermission(ctx, user.ID, req.ID, mustRead)
		if err != nil {
			return err
		}
		todoList, err = s.repo.GetTODOList(ctx, req.ID)
		if err != nil {
			return err
		}
		if todoList == nil {
			return errors.NewInternal(fmt.Errorf("list %s doesn't exist, bu present in acl", req.ID))
		}
		return nil
	})
	if err != nil {
		return nil, nil, err
	}
	return todoList, acl, nil
}

func (s *service) AddItem(ctx context.Context, req *ItemAddRequest) errors.Err {
	user, err := auth.UserFromCtxOrErr(ctx)
	if err != nil {
		return err
	}
	return s.txMgr.InTx(ctx).Do(func(ctx context.Context) error {
		_, err := s.assureUserPermission(ctx, user.ID, req.ListID, mustWrite)
		if err != nil {
			return err
		}
		list, err := s.repo.GetTODOList(ctx, req.ListID)
		if err != nil {
			return err
		}
		err = s.assureCanAddItem(list.Items, req.Text)
		if err != nil {
			return err
		}
		if list == nil {
			return errors.NewInternal(fmt.Errorf("list %s doesn't exist, but present in acl", req.ListID))
		}
		item := &model.ListItem{
			ID:   model.ListItemID(util.GenerateID()),
			Text: req.Text,
		}
		var newItems []*model.ListItem
		if req.Mode == ItemPrepend {
			newItems = append(newItems, item)
			newItems = append(newItems, list.Items...)
		} else {
			newItems = append(list.Items, item)
		}
		list.Items = newItems
		return s.repo.SaveTODOList(ctx, list)
	})
}

func (s *service) RemoveItem(ctx context.Context, req *ItemRemoveRequest) errors.Err {
	user, err := auth.UserFromCtxOrErr(ctx)
	if err != nil {
		return err
	}
	return s.txMgr.InTx(ctx).Do(func(ctx context.Context) error {
		_, err := s.assureUserPermission(ctx, user.ID, req.ListID, mustWrite)
		if err != nil {
			return err
		}
		list, err := s.repo.GetTODOList(ctx, req.ListID)
		if err != nil {
			return err
		}
		if list == nil {
			return errors.NewInternal(fmt.Errorf("list %s doesn't exist, but present in acl", req.ListID))
		}
		var newItems []*model.ListItem
		for _, it := range list.Items {
			if it.ID != req.ItemID {
				newItems = append(newItems, it)
			}
		}
		list.Items = newItems
		return s.repo.SaveTODOList(ctx, list)
	})
}

func (s *service) GetListUsers(ctx context.Context, req *GetListACLRequest) ([]*model.ACLEntry, errors.Err) {
	user, err := auth.UserFromCtxOrErr(ctx)
	if err != nil {
		return nil, err
	}
	var users []*model.ACLEntry
	err = s.txMgr.InTx(ctx, db.TxRO()).Do(func(ctx context.Context) error {
		_, err := s.assureUserPermission(ctx, user.ID, req.ID, mustInvite)
		if err != nil {
			return err
		}
		users, err = s.repo.ListACLByList(ctx, req.ID)
		return err
	})
	return users, err
}

func (s *service) GetUserLists(ctx context.Context, req *GetUserListsRequest) ([]*model.ACLEntry, errors.Err) {
	user, err := auth.UserFromCtxOrErr(ctx)
	if err != nil {
		return nil, err
	}
	var acl []*model.ACLEntry
	err = s.txMgr.InTx(ctx, db.TxRO()).Do(func(ctx context.Context) (err error) {
		acl, err = s.repo.ListACLByUser(ctx, user.ID)
		return err
	})
	if err != nil {
		return nil, err
	}
	return acl, nil
}

func (s *service) InviteUser(ctx context.Context, req *InviteRequest) errors.Err {
	if !req.Access.Grantable() {
		return errors.NewBadRequest(fmt.Sprintf("bad access mode: %s", req.Access))
	}
	user, err := auth.UserFromCtxOrErr(ctx)
	if err != nil {
		return err
	}
	if user.ID == req.Invitee {
		return errors.NewBadRequest("cannot grant access to yourself")
	}
	return s.txMgr.InTx(ctx).Do(func(ctx context.Context) error {
		myACLEntry, err := s.assureUserPermission(ctx, user.ID, req.ListID, mustInvite)
		if err != nil {
			return err
		}
		inviteeACL, err := s.repo.GetACL(ctx, req.Invitee, req.ListID)
		if err != nil {
			return err
		}
		if inviteeACL == nil {
			u, err := s.repo.GetUser(ctx, req.Invitee)
			if err != nil {
				return err
			}
			if u == nil {
				return errors.NewNotFound(fmt.Sprintf("user %s not found in service", req.Invitee))
			}
			inviteeACL = &model.ACLEntry{
				User:     req.Invitee,
				Mode:     req.Access,
				ListID:   req.ListID,
				Alias:    myACLEntry.Alias,
				Inviter:  user.ID,
				Accepted: false,
			}
			return s.repo.SaveACLEntry(ctx, inviteeACL)
		}
		if inviteeACL.Mode == req.Access {
			return nil
		}
		inviteeACL.Mode = req.Access
		return s.repo.SaveACLEntry(ctx, inviteeACL)
	})
}

func (s *service) AcceptAndRenameList(ctx context.Context, req *AcceptAndRenameListRequest) errors.Err {
	user, err := auth.UserFromCtxOrErr(ctx)
	if err != nil {
		return err
	}
	return s.txMgr.InTx(ctx).Do(func(ctx context.Context) error {
		acl, err := s.repo.GetACL(ctx, user.ID, req.ListID)
		if err != nil {
			return err
		}
		if acl == nil {
			return errors.NewNotFound(fmt.Sprintf("no pending invitations to list %s", req.ListID))
		}
		if acl.Accepted && acl.Alias == req.Alias {
			return nil
		}
		err = s.assureCanCreateList(ctx, user.ID, req.Alias, req.ListID)
		if err != nil {
			return err
		}
		acl.Accepted = true
		acl.Alias = req.Alias
		return s.repo.SaveACLEntry(ctx, acl)
	})
}

func (s *service) RemoveList(ctx context.Context, req *RemoveListRequest) errors.Err {
	user, err := auth.UserFromCtxOrErr(ctx)
	if err != nil {
		return err
	}
	return s.txMgr.InTx(ctx).Do(func(ctx context.Context) error {
		acl, err := s.repo.GetACL(ctx, user.ID, req.ID)
		if err != nil {
			return err
		}
		if acl == nil {
			return nil
		}
		var aclToRemove []*model.ACLEntry
		removeList := false
		if acl.Mode == model.AccessModeOwner {
			removeList = true
			aclToRemove, err = s.repo.ListACLByList(ctx, req.ID)
			if err != nil {
				return err
			}
		} else {
			aclToRemove = []*model.ACLEntry{acl}
		}
		for _, entry := range aclToRemove {
			err = s.repo.DeleteACL(ctx, entry.User, entry.ListID)
			if err != nil {
				return err
			}
		}
		if removeList {
			return s.repo.DeleteTODOList(ctx, req.ID)
		}
		return nil
	})
}

func (s *service) RevokeInvitation(ctx context.Context, req *InvitationRevokeRequest) errors.Err {
	user, err := auth.UserFromCtxOrErr(ctx)
	if err != nil {
		return err
	}
	if user.ID == req.Invitee {
		return errors.NewBadRequest(fmt.Sprintf("cannot revoke invitation for yourself"))
	}
	return s.txMgr.InTx(ctx).Do(func(ctx context.Context) error {
		_, err := s.assureUserPermission(ctx, user.ID, req.ListID, mustInvite)
		if err != nil {
			return err
		}
		toRevoke, err := s.repo.GetACL(ctx, req.Invitee, req.ListID)
		if err != nil {
			return err
		}
		if toRevoke == nil {
			return nil
		}
		if toRevoke.Mode == model.AccessModeOwner {
			return errors.NewInternal(fmt.Errorf(
				"should never happen: list %s have two owners: %s and %s", req.ListID, req.Invitee, user.ID))
		}
		return s.repo.DeleteACL(ctx, req.Invitee, req.ListID)
	})
}
