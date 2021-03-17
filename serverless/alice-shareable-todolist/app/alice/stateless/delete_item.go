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

func (h *Handler) deleteItemScenario(ctx context.Context, req *aliceapi.Req) (*aliceapi.Resp, errors.Err) {
	if req.NLU.Intents.DeleteItem == nil {
		return nil, nil
	}
	intnt := req.NLU.Intents.DeleteItem
	listName, ok := intnt.Slots.ListName.AsString()
	if !ok {
		return &aliceapi.Resp{
			Text: "Не поняла, из какого списка удалить",
		}, nil
	}
	itemText, ok := intnt.Slots.Item.AsString()
	if !ok {
		return &aliceapi.Resp{
			Text: "Не поняла, что удалить из списка",
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

	list, _, err := h.todoListService.Get(ctx, &todolist.ListGetRequest{ID: aclEntry.ListID})
	if err != nil {
		return nil, err
	}
	items := list.Items
	idx, ok = text.BestMatch(itemText, itemsMatchOpt(items))
	if !ok {
		return &aliceapi.Resp{
			Text: fmt.Sprintf("Я не нашла \"%s\" в \"%s\"", itemText, aclEntry.Alias),
		}, nil
	}
	item := items[idx]
	err = h.todoListService.RemoveItem(ctx, &todolist.ItemRemoveRequest{
		ListID: aclEntry.ListID,
		ItemID: item.ID,
	})
	if err != nil {
		return nil, err
	}
	return &aliceapi.Resp{
		Text: fmt.Sprintf("Готово, удалила \"%s\" из \"%s\"", item.Text, aclEntry.Alias),
	}, nil
}

type itemsMatchOpt []*model.ListItem

func (o itemsMatchOpt) Len() int {
	return len(o)
}

func (o itemsMatchOpt) TextOf(idx int) string {
	return o[idx].Text
}
