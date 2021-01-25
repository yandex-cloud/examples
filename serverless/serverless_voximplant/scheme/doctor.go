package scheme

import (
	"github.com/yandex-cloud/ydb-go-sdk"
	"github.com/yandex-cloud/ydb-go-sdk/table"
)

type Doctor struct {
	ID   string `json:"id"`
	Name string `json:"name"`
}

func (d *Doctor) ToYDB() ydb.Value {
	return ydb.StructValue(
		ydb.StructFieldValue("id", ydb.UTF8Value(d.ID)),
		ydb.StructFieldValue("name", ydb.UTF8Value(d.Name)),
	)
}

func (d *Doctor) FromYDB(result *table.Result) *Doctor {
	result.SeekItem("id")
	d.ID = utf8(result)
	result.SeekItem("name")
	d.Name = utf8(result)
	return d
}
