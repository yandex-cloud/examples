package scheme

import (
	"github.com/yandex-cloud/ydb-go-sdk"
	"github.com/yandex-cloud/ydb-go-sdk/table"
)

type Place struct {
	ID   string `json:"id"`
	Name string `json:"name"`
}

func (p *Place) ToYDB() ydb.Value {
	return ydb.StructValue(
		ydb.StructFieldValue("id", ydb.UTF8Value(p.ID)),
		ydb.StructFieldValue("name", ydb.UTF8Value(p.Name)),
	)
}

func (p *Place) FromYDB(result *table.Result) *Place {
	result.SeekItem("id")
	p.ID = utf8(result)
	result.SeekItem("name")
	p.Name = utf8(result)
	return p
}
