package scheme

import (
	"github.com/yandex-cloud/ydb-go-sdk/table"
)

func utf8(res *table.Result) string {
	if res.IsOptional() {
		return res.OUTF8()
	}
	return res.UTF8()
}

func date(res *table.Result) uint32 {
	if res.IsOptional() {
		return res.ODate()
	}
	return res.Date()
}

func datetime(res *table.Result) uint32 {
	if res.IsOptional() {
		return res.ODatetime()
	}
	return res.Datetime()
}
