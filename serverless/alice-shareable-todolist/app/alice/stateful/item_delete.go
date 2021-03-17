package stateful

import (
	"context"
	"fmt"

	aliceapi "github.com/yandex-cloud/examples/serverless/alice-shareable-todolist/app/alice/api"
	"github.com/yandex-cloud/examples/serverless/alice-shareable-todolist/app/errors"
	"github.com/yandex-cloud/examples/serverless/alice-shareable-todolist/app/model"
	"github.com/yandex-cloud/examples/serverless/alice-shareable-todolist/app/todolist"
)

type deleteItemAction struct {
	itemText string
	itemID   model.ListItemID
	listName string
	listID   model.TODOListID
}

func (h *Handler) deleteItemReqItem(ctx context.Context, req *aliceapi.Request) (*aliceapi.Response, errors.Err) {
	action := &deleteItemAction{
		listName: req.State.Session.ListName,
		listID:   req.State.Session.ListID,
	}
	if req.Request.Type == aliceapi.RequestTypeButton {
		if req.Request.Payload == nil || req.Request.Payload.ChooseItemID == "" {
			return nil, nil
		}
		action.itemText = req.Request.Payload.ChooseItemText
		action.itemID = req.Request.Payload.ChooseItemID
		return h.doDeleteItem(ctx, action)
	}
	action.itemText = req.Request.OriginalUtterance
	return h.doDeleteItem(ctx, action)
}

func (h *Handler) deleteItemReqList(ctx context.Context, req *aliceapi.Request) (*aliceapi.Response, errors.Err) {
	action := &deleteItemAction{
		itemText: req.State.Session.ItemText,
		itemID:   req.State.Session.ItemID,
	}
	if req.Request.Type == aliceapi.RequestTypeButton {
		if req.Request.Payload == nil || req.Request.Payload.ChooseListID == "" {
			return nil, nil
		}
		action.listID = req.Request.Payload.ChooseListID
		action.listName = req.Request.Payload.ChooseListName
		return h.doDeleteItem(ctx, action)
	}
	action.listName = req.Request.OriginalUtterance
	return h.doDeleteItem(ctx, action)
}

func (h *Handler) deleteItemFromScratch(ctx context.Context, req *aliceapi.Request) (*aliceapi.Response, errors.Err) {
	if req.Request.Type != aliceapi.RequestTypeSimple {
		return nil, nil
	}
	intnt := req.Request.NLU.Intents.DeleteItem
	if intnt == nil {
		return nil, nil
	}
	var action deleteItemAction
	listName, ok := intnt.Slots.ListName.AsString()
	if ok {
		action.listName = listName
	}
	itemText, ok := intnt.Slots.Item.AsString()
	if ok {
		action.itemText = itemText
	}
	return h.doDeleteItem(ctx, &action)
}

func (h *Handler) doDeleteItem(ctx context.Context, action *deleteItemAction) (*aliceapi.Response, errors.Err) {
	if action.listName == "" {
		// list not selected, going to ask user
		listButtons, err := h.suggestListButtons(ctx, filterWriteable)
		if err != nil {
			return nil, err
		}
		if len(listButtons) == 0 {
			return respondNoLists("У вас пока нет списков, которые вы могли бы редактировать"), nil
		}
		text := "Из какого списка удалить запись?"
		if action.itemText != "" {
			text = fmt.Sprintf("Из какого списка удалить \"%s\"?", action.itemText)
		}
		return &aliceapi.Response{
			Response: &aliceapi.Resp{Text: text, Buttons: listButtons},
			State: &aliceapi.StateData{
				ItemText: action.itemText,
				State:    aliceapi.StateDelItemReqList,
			},
		}, nil
	}
	if action.listID == "" {
		// list name is select, but not resolved to id
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
	}
	if action.itemText == "" {
		// item not selected, going to ask user
		buttons, err := h.suggestListItems(ctx, action.listID)
		if err != nil {
			return nil, err
		}
		return &aliceapi.Response{
			Response: &aliceapi.Resp{
				Text:    fmt.Sprintf("Что удалить из \"%s\"?", action.listName),
				Buttons: buttons,
			},
			State: &aliceapi.StateData{
				State:    aliceapi.StateDelItemReqItem,
				ListID:   action.listID,
				ListName: action.listName,
			},
		}, nil
	}
	if action.itemID == "" {
		// item is selected, but not resolved to id
		item, err := h.findItemByName(ctx, action.listID, action.itemText)
		if err != nil {
			return nil, err
		}
		if item == nil {
			return &aliceapi.Response{Response: &aliceapi.Resp{
				Text: fmt.Sprintf("Я не нашла \"%s\" в \"%s\"", action.itemText, action.listName),
			}}, nil
		}
		action.itemID = item.ID
		action.itemText = item.Text
	}
	err := h.todoListService.RemoveItem(ctx, &todolist.ItemRemoveRequest{
		ListID: action.listID,
		ItemID: action.itemID,
	})
	if err == nil {
		return &aliceapi.Response{Response: &aliceapi.Resp{
			Text: fmt.Sprintf("Готово, удалила \"%s\" из \"%s\"", action.itemText, action.listName),
		}}, nil
	}
	switch err.GetCode() {
	case errors.CodeUnauthorized:
		return &aliceapi.Response{
			Response: &aliceapi.Resp{Text: fmt.Sprintf(
				"Похоже, у вас нет прав на редактирование списка \"%s\"", action.listName,
			)},
		}, nil
	}
	return nil, err
}
