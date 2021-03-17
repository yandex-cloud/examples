package secure

import (
	"encoding/json"
	"fmt"

	"github.com/yandex-cloud/go-genproto/yandex/cloud/kms/v1"
)

type Config struct {
	SessionKeys []*SessionKeyPair `json:"session_keys"`
	OAuthSecret string            `json:"oauth_secret"`
}

type SessionKeyPair struct {
	HashKey  []byte `json:"hash"`
	BlockKey []byte `json:"block"`
}

func LoadConfig(deps Deps) (*Config, error) {
	sdk := deps.GetCloudSDK()
	kmsResp, err := sdk.KMSCrypto().SymmetricCrypto().Decrypt(deps.GetContext(), &kms.SymmetricDecryptRequest{
		KeyId:      deps.GetConfig().KMSKeyID,
		Ciphertext: deps.GetConfig().EncyptedSecrets,
	})
	if err != nil {
		return nil, fmt.Errorf("decrypting app secrets: %w", err)
	}
	resConf := &Config{}
	err = json.Unmarshal(kmsResp.Plaintext, resConf)
	if err != nil {
		//TODO: check if secret config content can be exposed in error message
		return nil, fmt.Errorf("unmarshalling secrets config: %w", err)
	}
	return resConf, nil
}
