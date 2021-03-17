package stateful

import (
	"context"

	aliceapi "github.com/yandex-cloud/examples/serverless/alice-shareable-todolist/app/alice/api"
	"github.com/yandex-cloud/examples/serverless/alice-shareable-todolist/app/errors"
)

type scenario = func(context.Context, *aliceapi.Request) (*aliceapi.Response, errors.Err)

func (h *Handler) setupScenarios() {
	h.stateScenarios = map[aliceapi.State]scenario{
		aliceapi.StateAddItemReqItem: h.addItemReqItem,
		aliceapi.StateAddItemReqList: h.addItemReqList,
		aliceapi.StateCreateReqName:  h.createRequireName,
		aliceapi.StateDelItemReqList: h.deleteItemReqList,
		aliceapi.StateDelItemReqItem: h.deleteItemReqItem,
		aliceapi.StateDelReqName:     h.deleteListReqList,
		aliceapi.StateDelReqConfirm:  h.deleteListReqConfirm,
		aliceapi.StateViewReqName:    h.viewListReqName,
	}
	h.scratchScenarios = []scenario{
		h.viewListFromScratch,
		h.listAllListsFromScratch,
		h.createFromScratch,
		h.addItemFromScratch,
		h.deleteListFromScratch,
		h.deleteItemFromScratch,
	}
}
