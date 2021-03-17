package stateful

import (
	"context"
	"fmt"

	aliceapi "github.com/yandex-cloud/examples/serverless/alice-shareable-todolist/app/alice/api"
	"github.com/yandex-cloud/examples/serverless/alice-shareable-todolist/app/errors"
)

func (h *Handler) listAllListsFromScratch(ctx context.Context, req *aliceapi.Request) (*aliceapi.Response, errors.Err) {
	if req.Request.Type != aliceapi.RequestTypeSimple {
		return nil, nil
	}
	intnt := req.Request.NLU.Intents.ListLists
	if intnt == nil {
		return nil, nil
	}
	acl, err := h.getUserListsCached(ctx)
	if err != nil {
		return nil, err
	}
	if len(acl) == 0 {
		return respondNoLists("У вас пока нет списков"), nil
	}
	text := "Ваши списки:\n"
	for _, entry := range acl {
		text = text + fmt.Sprintf("%s\n", entry.Alias)
	}
	return &aliceapi.Response{Response: &aliceapi.Resp{Text: text}}, nil
}
