package stateful

import (
	"context"
	"fmt"

	aliceapi "github.com/yandex-cloud/examples/serverless/alice-shareable-todolist/app/alice/api"
	"github.com/yandex-cloud/examples/serverless/alice-shareable-todolist/app/errors"
	"github.com/yandex-cloud/examples/serverless/alice-shareable-todolist/app/model"
	"github.com/yandex-cloud/examples/serverless/alice-shareable-todolist/app/todolist"
)

type deleteListAction struct {
	listID    model.TODOListID
	listName  string
	confirmed bool
}

func (h *Handler) deleteListFromScratch(ctx context.Context, req *aliceapi.Request) (*aliceapi.Response, errors.Err) {
	if req.Request.Type != aliceapi.RequestTypeSimple {
		return nil, nil
	}
	intnt := req.Request.NLU.Intents.DeleteList
	if intnt == nil {
		return nil, nil
	}
	var action deleteListAction
	listName, ok := intnt.Slots.ListName.AsString()
	if ok {
		action.listName = listName
	}
	return h.doDeleteList(ctx, &action)
}

func (h *Handler) deleteListReqList(ctx context.Context, req *aliceapi.Request) (*aliceapi.Response, errors.Err) {
	action := &deleteListAction{}
	if req.Request.Type == aliceapi.RequestTypeButton {
		if req.Request.Payload.ChooseListName == "" {
			return nil, nil
		}
		action.listID = req.Request.Payload.ChooseListID
		action.listName = req.Request.Payload.ChooseListName
		return h.doDeleteList(ctx, action)
	}
	action.listName = req.Request.OriginalUtterance
	return h.doDeleteList(ctx, action)
}

func (h *Handler) deleteListReqConfirm(ctx context.Context, req *aliceapi.Request) (*aliceapi.Response, errors.Err) {
	if req.Request.Type != aliceapi.RequestTypeSimple {
		return nil, nil
	}
	if req.Request.NLU.Intents.Confirm == nil {
		// fallback to "didn't recognize what do you want" since explicit rejection is handled on a higher level
		return nil, nil
	}
	return h.doDeleteList(ctx, &deleteListAction{
		listName:  req.State.Session.ListName,
		listID:    req.State.Session.ListID,
		confirmed: true,
	})
}

func (h *Handler) doDeleteList(ctx context.Context, action *deleteListAction) (*aliceapi.Response, errors.Err) {
	if action.listName == "" {
		// list not selected, going to ask user
		listButtons, err := h.suggestListButtons(ctx)
		if err != nil {
			return nil, err
		}
		if len(listButtons) == 0 {
			return respondNoLists("У вас пока нет ни одного списка"), nil
		}
		return &aliceapi.Response{
			Response: &aliceapi.Resp{
				Text:    "Какой список вы хотите удалить?",
				Buttons: listButtons,
			},
			State: &aliceapi.StateData{
				State: aliceapi.StateDelReqName,
			},
		}, nil
	}
	if action.listID == "" {
		// list name selected but not resolved to id
		entry, err := h.findListByName(ctx, action.listName)
		if err != nil {
			return nil, err
		}
		if entry == nil {
			return &aliceapi.Response{Response: &aliceapi.Resp{
				Text: fmt.Sprintf("Я не нашла у вас список \"%s\"", action.listName),
			}}, nil
		}
		action.listID = entry.ListID
		action.listName = entry.Alias
	}
	if !action.confirmed {
		return &aliceapi.Response{
			Response: &aliceapi.Resp{
				Text: fmt.Sprintf("Вы точно хотите удалить \"%s\"?", action.listName),
			},
			State: &aliceapi.StateData{
				State:    aliceapi.StateDelReqConfirm,
				ListID:   action.listID,
				ListName: action.listName,
			},
		}, nil
	}
	err := h.todoListService.RemoveList(ctx, &todolist.RemoveListRequest{ID: action.listID})
	if err == nil {
		return &aliceapi.Response{Response: &aliceapi.Resp{
			Text: fmt.Sprintf("Готово, удалила список \"%s\"", action.listName),
		}}, nil
	}
	return nil, err
}
