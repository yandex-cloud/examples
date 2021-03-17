package cloud

import (
	ycsdk "github.com/yandex-cloud/go-sdk"
)

func NewSDK(deps Deps) (*ycsdk.SDK, error) {
	return ycsdk.Build(deps.GetContext(), ycsdk.Config{Credentials: ycsdk.InstanceServiceAccount()})
}
