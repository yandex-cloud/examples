package scheme

import (
	"github.com/yandex-cloud/ydb-go-sdk"
	"github.com/yandex-cloud/ydb-go-sdk/table"
)

type Specialization struct {
	ID   string `json:"id"`
	Name string `json:"name"`
}

func (s *Specialization) ToYDB() ydb.Value {
	return ydb.StructValue(
		ydb.StructFieldValue("id", ydb.UTF8Value(s.ID)),
		ydb.StructFieldValue("name", ydb.UTF8Value(s.Name)),
	)
}

func (s *Specialization) FromYDB(result *table.Result) *Specialization {
	result.SeekItem("id")
	s.ID = utf8(result)
	result.SeekItem("name")
	s.Name = utf8(result)
	return s
}
