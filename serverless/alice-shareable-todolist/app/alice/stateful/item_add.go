package stateful

import (
	"context"
	"fmt"

	aliceapi "github.com/yandex-cloud/examples/serverless/alice-shareable-todolist/app/alice/api"
	"github.com/yandex-cloud/examples/serverless/alice-shareable-todolist/app/errors"
	"github.com/yandex-cloud/examples/serverless/alice-shareable-todolist/app/model"
	"github.com/yandex-cloud/examples/serverless/alice-shareable-todolist/app/todolist"
)

type addItemAction struct {
	itemText string
	listID   model.TODOListID
	listName string
}

func (h *Handler) addItemFromScratch(ctx context.Context, req *aliceapi.Request) (*aliceapi.Response, errors.Err) {
	if req.Request.Type != aliceapi.RequestTypeSimple {
		return nil, nil
	}
	intnt := req.Request.NLU.Intents.AddItem
	if intnt == nil {
		return nil, nil
	}
	var action addItemAction
	listName, ok := intnt.Slots.ListName.AsString()
	if ok {
		action.listName = listName
	}
	itemText, ok := intnt.Slots.Item.AsString()
	if ok {
		action.itemText = itemText
	}
	return h.doAddItem(ctx, &action)
}

func (h *Handler) addItemReqItem(ctx context.Context, req *aliceapi.Request) (*aliceapi.Response, errors.Err) {
	if req.Request.Type != aliceapi.RequestTypeSimple {
		return nil, nil
	}
	action := &addItemAction{
		itemText: req.Request.OriginalUtterance,
		listID:   req.State.Session.ListID,
		listName: req.State.Session.ListName,
	}
	return h.doAddItem(ctx, action)
}

func (h *Handler) addItemReqList(ctx context.Context, req *aliceapi.Request) (*aliceapi.Response, errors.Err) {
	action := &addItemAction{
		itemText: req.State.Session.ItemText,
	}
	if req.Request.Type == aliceapi.RequestTypeButton {
		if pl := req.Request.Payload; pl != nil && pl.ChooseListID != "" {
			action.listID = pl.ChooseListID
			action.listName = pl.ChooseListName
		} else {
			return nil, nil
		}
	} else {
		action.listName = req.Request.OriginalUtterance
	}

	return h.doAddItem(ctx, action)
}

func (h *Handler) doAddItem(ctx context.Context, action *addItemAction) (*aliceapi.Response, errors.Err) {
	if action.listName == "" {
		listButtons, err := h.suggestListButtons(ctx, filterWriteable)
		if err != nil {
			return nil, err
		}
		if len(listButtons) == 0 {
			return respondNoLists("У вас пока нет списков, которые вы могли бы редактировать"), nil
		}
		text := "В какой список добавить запись?"
		if action.itemText != "" {
			text = fmt.Sprintf("В какой список записать \"%s\"?", action.itemText)
		}
		return &aliceapi.Response{
			Response: &aliceapi.Resp{Text: text, Buttons: listButtons},
			State:    &aliceapi.StateData{ItemText: action.itemText, State: aliceapi.StateAddItemReqList},
		}, nil
	}
	if action.listID == "" {
		entry, err := h.findListByName(ctx, action.listName)
		if err != nil {
			return nil, err
		}
		if entry == nil {
			return &aliceapi.Response{
				Response: &aliceapi.Resp{
					Text: fmt.Sprintf("Я не нашла у вас список \"%\"", action.listName),
				},
			}, nil
		}
		action.listID = entry.ListID
		action.listName = entry.Alias
	}
	if action.itemText == "" {
		return &aliceapi.Response{
			Response: &aliceapi.Resp{Text: fmt.Sprintf("Что записать в \"%s\"?", action.listName)},
			State: &aliceapi.StateData{
				State:    aliceapi.StateAddItemReqItem,
				ListID:   action.listID,
				ListName: action.listName,
			},
		}, nil
	}
	err := h.todoListService.AddItem(ctx, &todolist.ItemAddRequest{
		ListID: action.listID,
		Text:   action.itemText,
		Mode:   todolist.ItemAppend,
	})
	if err == nil {
		return &aliceapi.Response{
			Response: &aliceapi.Resp{
				Text: fmt.Sprintf("Готово, добавила \"%s\" в \"%s\"", action.itemText, action.listName),
			},
		}, nil
	}
	switch err.GetCode() {
	case errors.CodeUnauthorized:
		return &aliceapi.Response{
			Response: &aliceapi.Resp{Text: fmt.Sprintf(
				"Похоже, у вас нет прав на редактирование списка \"%s\"", action.listName,
			)},
		}, nil
	case errors.CodeDuplicateName:
		dupErr := err.(*errors.DuplicateName)
		return &aliceapi.Response{Response: &aliceapi.Resp{
			Text: fmt.Sprintf("В этом списке уже есть похожий пункт: \"%s\". Попробуйте добавить что-нибудь другое", dupErr.Name),
		}}, nil
	case errors.CodeLimitExceeded:
		return &aliceapi.Response{Response: &aliceapi.Resp{
			Text: fmt.Sprintf("В этом списке слишком много пунктов. Чтобы записать что-то нужное - сначала удалите что-нибудь ненужное"),
		}}, nil
	}
	return nil, err
}
