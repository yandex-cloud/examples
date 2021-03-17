package api

type Intents struct {
	Confirm    *EmptyObj         `json:"YANDEX.CONFIRM"`
	Reject     *EmptyObj         `json:"YANDEX.REJECT"`
	AddItem    *IntentAddItem    `json:"list_item_add"`
	DeleteItem *IntentDeleteItem `json:"list_item_delete"`
	ViewList   *IntentViewList   `json:"list_view"`
	CreateList *IntentCreateList `json:"list_create"`
	DeleteList *IntentDeleteList `json:"list_delete"`
	ListLists  *EmptyObj         `json:"list_lists"`
	Cancel     *EmptyObj         `json:"cancel"`
}

type IntentCreateList struct {
	Slots IntentCreateListSlots `json:"slots"`
}

type IntentCreateListSlots struct {
	ListName *Slot `json:"listName"`
}

type IntentDeleteList struct {
	Slots IntentDeleteListSlots `json:"slots"`
}

type IntentDeleteListSlots struct {
	ListName *Slot `json:"listName"`
}

type IntentAddItem struct {
	Slots IntentAddItemSlots `json:"slots"`
}

type IntentAddItemSlots struct {
	Item     *Slot `json:"item"`
	ListName *Slot `json:"listName"`
}

type IntentDeleteItem struct {
	Slots IntentDeleteItemSlots `json:"slots"`
}

type IntentDeleteItemSlots struct {
	Item     *Slot `json:"item"`
	ListName *Slot `json:"listName"`
}

type IntentViewList struct {
	Slots IntentViewListSlots `json:"slots"`
}

type IntentViewListSlots struct {
	ListName *Slot `json:"listName"`
}
