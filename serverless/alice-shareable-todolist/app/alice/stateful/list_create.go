package stateful

import (
	"context"
	"fmt"

	aliceapi "github.com/yandex-cloud/examples/serverless/alice-shareable-todolist/app/alice/api"
	"github.com/yandex-cloud/examples/serverless/alice-shareable-todolist/app/errors"
	"github.com/yandex-cloud/examples/serverless/alice-shareable-todolist/app/todolist"
)

type createAction struct {
	name string
}

func (h *Handler) createFromScratch(ctx context.Context, req *aliceapi.Request) (*aliceapi.Response, errors.Err) {
	if req.Request.Type == aliceapi.RequestTypeButton {
		if req.Request.Payload == nil || !req.Request.Payload.CreateList {
			return nil, nil
		}
		return h.doCreate(ctx, &createAction{name: req.Request.Payload.ChooseListName})
	}
	intnt := req.Request.NLU.Intents.CreateList
	if intnt == nil {
		return nil, nil
	}
	var action createAction
	name, ok := intnt.Slots.ListName.AsString()
	if ok {
		action.name = name
	}
	return h.doCreate(ctx, &createAction{name: name})
}

func (h *Handler) createRequireName(ctx context.Context, req *aliceapi.Request) (*aliceapi.Response, errors.Err) {
	if req.Request.Type != aliceapi.RequestTypeSimple {
		return nil, nil
	}
	action := &createAction{name: req.Request.OriginalUtterance}
	return h.doCreate(ctx, action)
}

func (h *Handler) doCreate(ctx context.Context, action *createAction) (*aliceapi.Response, errors.Err) {
	if action.name == "" {
		return &aliceapi.Response{
			Response: &aliceapi.Resp{Text: "Как назвать новый список?"},
			State:    &aliceapi.StateData{State: aliceapi.StateCreateReqName},
		}, nil
	}
	_, err := h.todoListService.Create(ctx, &todolist.ListCreateRequest{Name: action.name})
	if err == nil {
		return &aliceapi.Response{
			Response: &aliceapi.Resp{
				Text: fmt.Sprintf("Готово, создала список \"%s\"", action.name),
			},
		}, nil
	}
	switch err.GetCode() {
	case errors.CodeDuplicateName:
		dupErr := err.(*errors.DuplicateName)
		return &aliceapi.Response{
			Response: &aliceapi.Resp{Text: fmt.Sprintf(
				"У вас уже есть список с похожим названием - \"%s\". Попробуйте придумать другое название",
				dupErr.Name,
			)},
			State: &aliceapi.StateData{State: aliceapi.StateCreateReqName},
		}, nil
	case errors.CodeLimitExceeded:
		return &aliceapi.Response{Response: &aliceapi.Resp{
			Text: "У вас слишком много списков",
		}}, nil
	}
	return nil, err
}
