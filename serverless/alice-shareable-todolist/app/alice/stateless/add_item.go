package stateless

import (
	"context"
	"fmt"

	aliceapi "github.com/yandex-cloud/examples/serverless/alice-shareable-todolist/app/alice/api"
	"github.com/yandex-cloud/examples/serverless/alice-shareable-todolist/app/alice/text"
	"github.com/yandex-cloud/examples/serverless/alice-shareable-todolist/app/errors"
	"github.com/yandex-cloud/examples/serverless/alice-shareable-todolist/app/model"
	"github.com/yandex-cloud/examples/serverless/alice-shareable-todolist/app/todolist"
)

func (h *Handler) addItemScenario(ctx context.Context, req *aliceapi.Req) (*aliceapi.Resp, errors.Err) {
	if req.NLU.Intents.AddItem == nil {
		return nil, nil
	}
	intnt := req.NLU.Intents.AddItem
	listName, ok := intnt.Slots.ListName.AsString()
	if !ok {
		return &aliceapi.Resp{
			Text: "Не поняла, в какой список добавить",
		}, nil
	}
	itemText, ok := intnt.Slots.Item.AsString()
	if !ok {
		return &aliceapi.Resp{
			Text: "Не поняла, что добавить в список",
		}, nil
	}
	acl, err := h.todoListService.GetUserLists(ctx, &todolist.GetUserListsRequest{})
	if err != nil {
		return nil, err
	}
	idx, ok := text.BestMatch(listName, text.ACLMatcher(acl))
	if !ok {
		return &aliceapi.Resp{
			Text: fmt.Sprintf("Я не нашла у вас список \"%s\"", listName),
		}, nil
	}
	aclEntry := acl[idx]
	if !aclEntry.Mode.CanWrite() {
		return &aliceapi.Resp{
			Text: fmt.Sprintf("Вы не можете редактировать список \"%s\"", aclEntry.Alias),
		}, nil
	}
	err = h.todoListService.AddItem(ctx, &todolist.ItemAddRequest{
		ListID: aclEntry.ListID,
		Text:   itemText,
		Mode:   todolist.ItemAppend,
	})
	if err != nil {
		return nil, err
	}
	return &aliceapi.Resp{
		Text: fmt.Sprintf("Готово, добавила \"%s\" в \"%s\"", itemText, aclEntry.Alias),
	}, nil
}

func (h *Handler) findListByName(acl []*model.ACLEntry, name string) *model.ACLEntry {
	idx, ok := text.BestMatch(name, text.ACLMatcher(acl))
	if ok {
		return acl[idx]
	}
	return nil
}

func nonEmpty(ss ...string) string {
	for _, s := range ss {
		if s != "" {
			return s
		}
	}
	return ""
}
