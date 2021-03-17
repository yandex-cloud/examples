package todolist

import (
	"context"

	"github.com/yandex-cloud/examples/serverless/alice-shareable-todolist/app/alice/text"
	"github.com/yandex-cloud/examples/serverless/alice-shareable-todolist/app/errors"
	"github.com/yandex-cloud/examples/serverless/alice-shareable-todolist/app/model"
)

func (s *service) assureCanAddItem(items []*model.ListItem, newItem string) errors.Err {
	if len(items) >= maxItemsPerList {
		return errors.NewLimitExceeded("Too many items in list")
	}
	dupIdx, ok := text.BestMatch(newItem, text.ListItemsMatcher(items), text.MatchMinRatio(0.9))
	if ok {
		return errors.NewDuplicateName(items[dupIdx].Text)
	}
	return nil
}

func (s *service) assureCanCreateList(ctx context.Context, userID model.UserID, name string, exceptID model.TODOListID) error {
	acl, err := s.repo.ListACLByUser(ctx, userID)
	if err != nil {
		return err
	}
	var acceptedACL []*model.ACLEntry
	for _, e := range acl {
		if e.Accepted && e.ListID != exceptID {
			acceptedACL = append(acceptedACL, e)
		}
	}
	if len(acceptedACL) >= maxListsPerUser {
		return errors.NewLimitExceeded("Too many lists")
	}
	dupIdx, ok := text.BestMatch(name, text.ACLMatcher(acceptedACL),
		text.MatchMinRatio(0.9), text.MatchOptPrefix("список"))
	if ok {
		return errors.NewDuplicateName(acceptedACL[dupIdx].Alias)
	}
	return nil
}

func mustRead(mode model.AccessMode) errors.Err {
	if !mode.CanRead() {
		return errors.NewUnauthorized("user cannot read list")
	}
	return nil
}

func mustWrite(mode model.AccessMode) errors.Err {
	if !mode.CanWrite() {
		return errors.NewUnauthorized("user cannot modify list")
	}
	return nil
}

func mustInvite(mode model.AccessMode) errors.Err {
	if !mode.CanInvite() {
		return errors.NewUnauthorized("user cannot work with invitations")
	}
	return nil
}

func (s *service) assureUserPermission(ctx context.Context, userID model.UserID, listID model.TODOListID, perm func(mode model.AccessMode) errors.Err) (*model.ACLEntry, error) {
	acl, err := s.repo.GetACL(ctx, userID, listID)
	if err != nil || acl == nil || !acl.Accepted {
		return nil, perm("")
	}
	return acl, perm(acl.Mode)
}
