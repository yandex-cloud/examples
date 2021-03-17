package stateful

import (
	"context"
	"fmt"

	aliceapi "github.com/yandex-cloud/examples/serverless/alice-shareable-todolist/app/alice/api"
	"github.com/yandex-cloud/examples/serverless/alice-shareable-todolist/app/errors"
	"github.com/yandex-cloud/examples/serverless/alice-shareable-todolist/app/model"
)

type viewListAction struct {
	listID   model.TODOListID
	listName string
}

func (h *Handler) viewListFromScratch(ctx context.Context, req *aliceapi.Request) (*aliceapi.Response, errors.Err) {
	if req.Request.Type != aliceapi.RequestTypeSimple {
		return nil, nil
	}
	intnt := req.Request.NLU.Intents.ViewList
	if intnt == nil {
		return nil, nil
	}
	var action viewListAction
	listName, ok := intnt.Slots.ListName.AsString()
	if ok {
		action.listName = listName
	}
	return h.doViewList(ctx, &action)
}

func (h *Handler) viewListReqName(ctx context.Context, req *aliceapi.Request) (*aliceapi.Response, errors.Err) {
	action := &viewListAction{}
	if req.Request.Type == aliceapi.RequestTypeButton {
		if req.Request.Payload.ChooseListName == "" {
			return nil, nil
		}
		action.listName = req.Request.Payload.ChooseListName
		action.listID = req.Request.Payload.ChooseListID
		return h.doViewList(ctx, action)
	}
	action.listName = req.Request.OriginalUtterance
	return h.doViewList(ctx, action)
}

func (h *Handler) doViewList(ctx context.Context, action *viewListAction) (*aliceapi.Response, errors.Err) {
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
				Text:    fmt.Sprintf("Какой список вы хотите посмотреть?"),
				Buttons: listButtons,
			},
			State: &aliceapi.StateData{State: aliceapi.StateViewReqName},
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
	_, list, err := h.getListCached(ctx, action.listID)
	if err != nil {
		return nil, err
	}
	items := list.Items
	if len(items) == 0 {
		return &aliceapi.Response{Response: &aliceapi.Resp{
			Text: fmt.Sprintf("В \"%s\" пока ничего нет", action.listName),
		}}, nil
	}
	text := fmt.Sprintf("%s:\n", action.listName)
	for idx, item := range items {
		text += fmt.Sprintf("%d. %s\n", idx+1, item.Text)
	}
	return &aliceapi.Response{Response: &aliceapi.Resp{Text: text}}, nil
}
