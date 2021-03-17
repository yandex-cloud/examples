package web

import (
	"fmt"

	"github.com/yandex-cloud/examples/serverless/alice-shareable-todolist/app/errors"
	webmodels "github.com/yandex-cloud/examples/serverless/alice-shareable-todolist/app/generated/openapi/models"
	"github.com/yandex-cloud/examples/serverless/alice-shareable-todolist/app/model"
)

var accessModeToWebMap = map[model.AccessMode]webmodels.AccessMode{
	model.AccessModeRead:      webmodels.AccessModeR,
	model.AccessModeOwner:     webmodels.AccessModeO,
	model.AccessModeReadWrite: webmodels.AccessModeRW,
}
var accessModeFromWebMap = map[webmodels.AccessMode]model.AccessMode{}

func init() {
	for k, v := range accessModeToWebMap {
		accessModeFromWebMap[v] = k
	}
}

func accessModeToWeb(m model.AccessMode) webmodels.AccessMode {
	res, ok := accessModeToWebMap[m]
	if !ok {
		panic(fmt.Errorf("not found web model for access mode %s", m))
	}
	return res
}

func inplaceListShortToWeb(acl *model.ACLEntry, res *webmodels.ListShort) {
	res.Access = accessModeToWeb(acl.Mode)
	res.ID = string(acl.ListID)
	res.Inviter = string(acl.Inviter)
	res.Name = acl.Alias
	res.Accepted = acl.Accepted
}

func listShortToWeb(acl *model.ACLEntry) *webmodels.ListShort {
	var res webmodels.ListShort
	inplaceListShortToWeb(acl, &res)
	return &res
}

func listShortToWebList(acl []*model.ACLEntry) []*webmodels.ListShort {
	res := make([]*webmodels.ListShort, 0, len(acl))
	for _, entry := range acl {
		res = append(res, listShortToWeb(entry))
	}
	return res
}

func listItemToWeb(item *model.ListItem) *webmodels.ListItem {
	return &webmodels.ListItem{
		ID:   string(item.ID),
		Text: string(item.Text),
	}
}

func listToWeb(acl *model.ACLEntry, list *model.TODOList) *webmodels.List {
	var res webmodels.List
	inplaceListShortToWeb(acl, &res.ListShort)
	res.Items = make([]*webmodels.ListItem, 0, len(list.Items))
	for _, item := range list.Items {
		res.Items = append(res.Items, listItemToWeb(item))
	}
	return &res
}

func listUsersToWeb(acl []*model.ACLEntry, me model.UserID) []*webmodels.ListUser {
	res := make([]*webmodels.ListUser, 0, len(acl))
	for _, entry := range acl {
		res = append(res, &webmodels.ListUser{
			AccessMode: accessModeToWeb(entry.Mode),
			UserName:   string(entry.User),
			Accepted:   entry.Accepted,
			Me:         me == entry.User,
		})
	}
	return res
}

func userInfoToWeb(user *model.User) *webmodels.User {
	return &webmodels.User{
		AvatarID: user.YandexAvatarID,
		Name:     user.Name,
	}
}

// From web

func accessModeFromWeb(mode webmodels.AccessMode) (model.AccessMode, errors.Err) {
	res, ok := accessModeFromWebMap[mode]
	if !ok {
		return "", errors.NewBadRequest(fmt.Sprintf("unknown access mode: %s", mode))
	}
	return res, nil
}
