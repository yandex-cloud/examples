package main

type slotsRequest struct {
	ClientID string

	Spec         string
	Place        string
	Date         string
	Doctors      []string
	ExcludeSlots []string
	CancelSlots  []string
}

type datesRequest struct {
	Spec  string
	Place string
}

type doctorsRequest struct {
	Spec  string
	Place string
	Date  string
}

type ackSlotRequest struct {
	ClientID    string
	SlotID      string
	CancelSlots []string
}

const (
	// gateway paths
	Specs   = "/specs"   // initial -> [{id, name}]
	Places  = "/places"  // initial -> [{id, name}]
	Dates   = "/dates"   // spec MUST be specified, place MAY be specified -> ["yyyy-MM-dd"]
	Doctors = "/doctors" // spec and date MUST be specified, place MAY be specified -> [{id, name}]

	// Next actions may contain `slots` section for further processing
	Slots   = "/slots"              // clientID, spec and date MUST be specified, place and doctor MAY be specified -> [{id, at}]
	AckSlot = "/slots/{slotId}/ack" // clientID, slotID - for ack, possible slots.cancel for additional cancel. -> [{at, place(name), spec(name), doctor(name)}]
)
