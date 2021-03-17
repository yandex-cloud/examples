package stateful

import (
	"context"

	aliceapi "github.com/yandex-cloud/examples/serverless/alice-shareable-todolist/app/alice/api"
	"github.com/yandex-cloud/examples/serverless/alice-shareable-todolist/app/alice/cache"
	"github.com/yandex-cloud/examples/serverless/alice-shareable-todolist/app/alice/text"
	"github.com/yandex-cloud/examples/serverless/alice-shareable-todolist/app/errors"
	"github.com/yandex-cloud/examples/serverless/alice-shareable-todolist/app/model"
	"github.com/yandex-cloud/examples/serverless/alice-shareable-todolist/app/todolist"
)

const maxButtons = 5

type listPredicate = func(entry *model.ACLEntry) bool

func filterWriteable(e *model.ACLEntry) bool {
	return e.Mode.CanWrite()
}

func (h *Handler) getListCached(ctx context.Context, id model.TODOListID) (*model.ACLEntry, *model.TODOList, errors.Err) {
	type listInfo struct {
		acl  *model.ACLEntry
		list *model.TODOList
	}
	res, err := cache.GetCachedForRequest(ctx, id, func() (interface{}, errors.Err) {
		list, acl, err := h.todoListService.Get(ctx, &todolist.ListGetRequest{ID: id})
		if err != nil {
			return nil, err
		}
		return &listInfo{acl: acl, list: list}, nil
	})
	if err != nil {
		return nil, nil, err
	}
	info := res.(*listInfo)
	return info.acl, info.list, nil
}

func (h *Handler) getUserListsCached(ctx context.Context) ([]*model.ACLEntry, errors.Err) {
	type userListsCacheKey struct{}
	res, err := cache.GetCachedForRequest(ctx, userListsCacheKey{}, func() (interface{}, errors.Err) {
		return h.todoListService.GetUserLists(ctx, &todolist.GetUserListsRequest{})
	})
	if err != nil {
		return nil, err
	}
	return res.([]*model.ACLEntry), nil
}

func (h *Handler) findListByName(ctx context.Context, name string) (*model.ACLEntry, errors.Err) {
	acl, err := h.getUserListsCached(ctx)
	if err != nil {
		return nil, err
	}
	idx, ok := text.BestMatch(name, text.ACLMatcher(acl), text.MatchOptPrefix("список"))
	if !ok {
		return nil, nil
	}
	return acl[idx], nil
}

func (h *Handler) findItemByName(ctx context.Context, listID model.TODOListID, itemText string) (*model.ListItem, errors.Err) {
	_, list, err := h.getListCached(ctx, listID)
	if err != nil {
		return nil, err
	}
	idx, ok := text.BestMatch(itemText, text.ListItemsMatcher(list.Items))
	if !ok {
		return nil, nil
	}
	return list.Items[idx], nil
}

func (h *Handler) suggestListButtons(ctx context.Context, filters ...listPredicate) ([]*aliceapi.Button, errors.Err) {
	acl, err := h.getUserListsCached(ctx)
	if err != nil {
		return nil, err
	}
	var buttons []*aliceapi.Button
	for _, entry := range acl {
		if !entry.Accepted {
			continue
		}
		drop := false
		for _, filter := range filters {
			if !filter(entry) {
				drop = true
				break
			}
		}
		if drop {
			continue
		}
		buttons = append(buttons, &aliceapi.Button{
			Title:   entry.Alias,
			Payload: &aliceapi.ButtonPayload{ChooseListID: entry.ListID, ChooseListName: entry.Alias},
			Hide:    true,
		})
		if len(buttons) >= maxButtons {
			break
		}
	}
	return buttons, nil
}

func (h *Handler) suggestListItems(ctx context.Context, id model.TODOListID) ([]*aliceapi.Button, errors.Err) {
	_, list, err := h.getListCached(ctx, id)
	if err != nil {
		return nil, err
	}
	var res []*aliceapi.Button
	for _, item := range list.Items {
		res = append(res, &aliceapi.Button{
			Title: item.Text,
			Payload: &aliceapi.ButtonPayload{
				ChooseItemID:   item.ID,
				ChooseItemText: item.Text,
			},
			Hide: true,
		})
		if len(res) >= maxButtons {
			break
		}
	}
	return res, nil
}

func respondNoLists(msg string) *aliceapi.Response {
	if msg == "" {
		msg = "У вас пока нет ни одного списка"
	}
	return &aliceapi.Response{
		Response: &aliceapi.Resp{
			Text: msg,
			Buttons: []*aliceapi.Button{{
				Title:   "Создать список",
				Payload: &aliceapi.ButtonPayload{CreateList: true},
				Hide:    true,
			}},
		},
	}
}
