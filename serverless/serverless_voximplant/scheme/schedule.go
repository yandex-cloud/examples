package scheme

import (
	"time"

	"github.com/yandex-cloud/ydb-go-sdk"
	"github.com/yandex-cloud/ydb-go-sdk/table"
)

type Entry struct {
	ID         string     `json:"id"`
	DoctorID   string     `json:"doctor_id,omitempty"`
	SpecID     string     `json:"spec_id,omitempty"`
	PlaceID    string     `json:"place_id,omitempty"`
	At         time.Time  `json:"at,omitempty"`
	Date       time.Time  `json:"date,omitempty"`
	Patient    *string    `json:"patient,omitempty"`
	BookedTill *time.Time `json:"booked_till,omitempty"`
}

func (e *Entry) ToYDB() ydb.Value {
	var fields = []ydb.StructValueOption{
		ydb.StructFieldValue("id", ydb.UTF8Value(e.ID)),
		ydb.StructFieldValue("doctor_id", ydb.UTF8Value(e.DoctorID)),
		ydb.StructFieldValue("spec_id", ydb.UTF8Value(e.SpecID)),
		ydb.StructFieldValue("place_id", ydb.UTF8Value(e.PlaceID)),
		ydb.StructFieldValue("at", ydb.DatetimeValue(ydb.Time(e.At).Datetime())),
		ydb.StructFieldValue("date", ydb.DatetimeValue(ydb.Time(e.Date).Date())),
	}
	if e.Patient != nil {
		fields = append(fields, ydb.StructFieldValue("patient", ydb.UTF8Value(*e.Patient)))
	}
	if e.BookedTill != nil {
		fields = append(fields, ydb.StructFieldValue("booked_till", ydb.DatetimeValue(ydb.Time(*e.BookedTill).Datetime())))
	}
	return ydb.StructValue(fields...)
}

func (e *Entry) FromYDB(result *table.Result) *Entry {
	if result.SeekItem("id") {
		e.ID = utf8(result)
	}

	if result.SeekItem("doctor_id") {
		e.DoctorID = utf8(result)
	}

	if result.SeekItem("spec_id") {
		e.SpecID = utf8(result)
	}

	if result.SeekItem("place_id") {
		e.PlaceID = utf8(result)
	}

	t := new(ydb.Time)

	if result.SeekItem("at") {
		_ = t.FromDatetime(datetime(result))
		e.At = time.Time(*t)
	}

	if result.SeekItem("date") {
		_ = t.FromDate(date(result))
		e.Date = time.Time(*t)
	}

	if result.SeekItem("patient") {
		p := utf8(result)
		if len(p) > 0 {
			e.Patient = &p
		}
	}

	if result.SeekItem("booked_till") {
		d := datetime(result)
		if d > 0 {
			_ = t.FromDatetime(d)
			b := time.Time(*t)
			if !b.IsZero() {
				e.BookedTill = &b
			}
		}
	}

	return e
}
