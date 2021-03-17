package stateless

import (
	"context"
	"fmt"

	aliceapi "github.com/yandex-cloud/examples/serverless/alice-shareable-todolist/app/alice/api"
	"github.com/yandex-cloud/examples/serverless/alice-shareable-todolist/app/alice/text"
	"github.com/yandex-cloud/examples/serverless/alice-shareable-todolist/app/errors"
	"github.com/yandex-cloud/examples/serverless/alice-shareable-todolist/app/todolist"
)

func (h *Handler) viewListScenario(ctx context.Context, req *aliceapi.Req) (*aliceapi.Resp, errors.Err) {
	if req.NLU.Intents.ViewList == nil {
		return nil, nil
	}
	intnt := req.NLU.Intents.ViewList
	listName, ok := intnt.Slots.ListName.AsString()
	if !ok {
		return &aliceapi.Resp{
			Text: "Не поняла, какой список вы хотите посмотреть",
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
	list, _, err := h.todoListService.Get(ctx, &todolist.ListGetRequest{aclEntry.ListID})
	items := list.Items
	if len(items) == 0 {
		return &aliceapi.Resp{
			Text: fmt.Sprintf("В \"%s\" пока ничего нет"),
		}, nil
	}
	text := fmt.Sprintf("%s:\n", aclEntry.Alias)
	for idx, item := range items {
		text += fmt.Sprintf("%d. %s\n", idx+1, item.Text)
	}
	return &aliceapi.Resp{
		Text: text,
	}, nil
}
