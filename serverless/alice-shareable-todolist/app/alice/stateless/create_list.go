package stateless

import (
	"context"
	"fmt"

	aliceapi "github.com/yandex-cloud/examples/serverless/alice-shareable-todolist/app/alice/api"
	"github.com/yandex-cloud/examples/serverless/alice-shareable-todolist/app/alice/text"
	"github.com/yandex-cloud/examples/serverless/alice-shareable-todolist/app/errors"
	"github.com/yandex-cloud/examples/serverless/alice-shareable-todolist/app/todolist"
)

func (h *Handler) createListScenario(ctx context.Context, req *aliceapi.Req) (*aliceapi.Resp, errors.Err) {
	if req.NLU.Intents.CreateList == nil {
		return nil, nil
	}
	intnt := req.NLU.Intents.CreateList
	listName, ok := intnt.Slots.ListName.AsString()
	if !ok {
		return &aliceapi.Resp{
			Text: "Не поняла, как назвать новый список",
		}, nil
	}
	acl, err := h.todoListService.GetUserLists(ctx, &todolist.GetUserListsRequest{})
	if err != nil {
		return nil, err
	}
	if len(acl) != 0 {
		idx, ok := text.BestMatch(listName, text.ACLMatcher(acl), text.MatchMinRatio(0.9))
		if ok {
			entry := acl[idx]
			return &aliceapi.Resp{
				Text: fmt.Sprintf("У вас уже есть список с похожим названием: %s", entry.Alias),
			}, nil
		}
	}
	_, err = h.todoListService.Create(ctx, &todolist.ListCreateRequest{Name: listName})
	if err != nil {
		return nil, err
	}
	return &aliceapi.Resp{
		Text: fmt.Sprintf("Готово, создала \"%s\"", listName),
	}, nil
}
