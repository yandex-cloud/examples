package stateless

import (
	"context"
	"fmt"

	aliceapi "github.com/yandex-cloud/examples/serverless/alice-shareable-todolist/app/alice/api"
	"github.com/yandex-cloud/examples/serverless/alice-shareable-todolist/app/errors"
	"github.com/yandex-cloud/examples/serverless/alice-shareable-todolist/app/todolist"
)

func (h *Handler) listListsScenario(ctx context.Context, req *aliceapi.Req) (*aliceapi.Resp, errors.Err) {
	if req.NLU.Intents.ListLists == nil {
		return nil, nil
	}
	acl, err := h.todoListService.GetUserLists(ctx, &todolist.GetUserListsRequest{})
	if err != nil {
		return nil, err
	}
	if len(acl) == 0 {
		return &aliceapi.Resp{
			Text: "У вас пока нет списков",
		}, nil
	}
	text := "Ваши списки:\n"
	for _, entry := range acl {
		text = text + fmt.Sprintf("%s\n", entry.Alias)
	}
	return &aliceapi.Resp{
		Text: text,
	}, nil
}
