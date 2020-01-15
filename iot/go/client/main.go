// Copyright (c) 2019 Yandex LLC. All rights reserved.

package main

import (
	"crypto/tls"
	"crypto/x509"
	"fmt"
	"path"
	"path/filepath"
)

const rootCA = `-----BEGIN CERTIFICATE-----
MIIFGTCCAwGgAwIBAgIQJMM7ZIy2SYxCBgK7WcFwnjANBgkqhkiG9w0BAQ0FADAf
MR0wGwYDVQQDExRZYW5kZXhJbnRlcm5hbFJvb3RDQTAeFw0xMzAyMTExMzQxNDNa
Fw0zMzAyMTExMzUxNDJaMB8xHTAbBgNVBAMTFFlhbmRleEludGVybmFsUm9vdENB
MIICIjANBgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEAgb4xoQjBQ7oEFk8EHVGy
1pDEmPWw0Wgw5nX9RM7LL2xQWyUuEq+Lf9Dgh+O725aZ9+SO2oEs47DHHt81/fne
5N6xOftRrCpy8hGtUR/A3bvjnQgjs+zdXvcO9cTuuzzPTFSts/iZATZsAruiepMx
SGj9S1fGwvYws/yiXWNoNBz4Tu1Tlp0g+5fp/ADjnxc6DqNk6w01mJRDbx+6rlBO
aIH2tQmJXDVoFdrhmBK9qOfjxWlIYGy83TnrvdXwi5mKTMtpEREMgyNLX75UjpvO
NkZgBvEXPQq+g91wBGsWIE2sYlguXiBniQgAJOyRuSdTxcJoG8tZkLDPRi5RouWY
gxXr13edn1TRDGco2hkdtSUBlajBMSvAq+H0hkslzWD/R+BXkn9dh0/DFnxVt4XU
5JbFyd/sKV/rF4Vygfw9ssh1ZIWdqkfZ2QXOZ2gH4AEeoN/9vEfUPwqPVzL0XEZK
r4s2WjU9mE5tHrVsQOZ80wnvYHYi2JHbl0hr5ghs4RIyJwx6LEEnj2tzMFec4f7o
dQeSsZpgRJmpvpAfRTxhIRjZBrKxnMytedAkUPguBQwjVCn7+EaKiJfpu42JG8Mm
+/dHi+Q9Tc+0tX5pKOIpQMlMxMHw8MfPmUjC3AAd9lsmCtuybYoeN2IRdbzzchJ8
l1ZuoI3gH7pcIeElfVSqSBkCAwEAAaNRME8wCwYDVR0PBAQDAgGGMA8GA1UdEwEB
/wQFMAMBAf8wHQYDVR0OBBYEFKu5xf+h7+ZTHTM5IoTRdtQ3Ti1qMBAGCSsGAQQB
gjcVAQQDAgEAMA0GCSqGSIb3DQEBDQUAA4ICAQAVpyJ1qLjqRLC34F1UXkC3vxpO
nV6WgzpzA+DUNog4Y6RhTnh0Bsir+I+FTl0zFCm7JpT/3NP9VjfEitMkHehmHhQK
c7cIBZSF62K477OTvLz+9ku2O/bGTtYv9fAvR4BmzFfyPDoAKOjJSghD1p/7El+1
eSjvcUBzLnBUtxO/iYXRNo7B3+1qo4F5Hz7rPRLI0UWW/0UAfVCO2fFtyF6C1iEY
/q0Ldbf3YIaMkf2WgGhnX9yH/8OiIij2r0LVNHS811apyycjep8y/NkG4q1Z9jEi
VEX3P6NEL8dWtXQlvlNGMcfDT3lmB+tS32CPEUwce/Ble646rukbERRwFfxXojpf
C6ium+LtJc7qnK6ygnYF4D6mz4H+3WaxJd1S1hGQxOb/3WVw63tZFnN62F6/nc5g
6T44Yb7ND6y3nVcygLpbQsws6HsjX65CoSjrrPn0YhKxNBscF7M7tLTW/5LK9uhk
yjRCkJ0YagpeLxfV1l1ZJZaTPZvY9+ylHnWHhzlq0FzcrooSSsp4i44DB2K7O2ID
87leymZkKUY6PMDa4GkDJx0dG4UXDhRETMf+NkYgtLJ+UIzMNskwVDcxO4kVL+Hi
Pj78bnC5yCw8P5YylR45LdxLzLO68unoXOyFz1etGXzszw8lJI9LNubYxk77mK8H
LpuQKbSbIERsmR+QqQ==
-----END CERTIFICATE-----
`

func NewTLSConfig(certsDir string) (*tls.Config, error) {
	// Certs part.
	certpool := x509.NewCertPool()
	certpool.AppendCertsFromPEM([]byte(rootCA))

	cert, err := tls.LoadX509KeyPair(path.Join(certsDir, "cert.pem"), path.Join(certsDir, "key.pem"))
	if err != nil {
		return nil, err
	}

	// Create tls.Config with desired tls properties
	return &tls.Config{
		MinVersion: tls.VersionTLS12,
		// RootCAs = certs used to verify server cert.
		RootCAs: certpool,
		// InsecureSkipVerify = verify that cert contents
		// match server. IP matches what is in cert etc.
		InsecureSkipVerify: false,
		// Certificates = list of certs client sends to server.
		Certificates: []tls.Certificate{cert},
	}, nil
}

func main() {
	var serverURL = fmt.Sprint("tls://mqtt-preprod.cloud.yandex.net", ":8883")

	const topicBaseName = "$devices/b9170i9m9cbn21sdapbi"

	currentDir, err := filepath.Abs("")
	if err != nil {
		panic(err)
	}
	// certs directory structure:
	//   /my_registry     Registry directory |currentDir|.
	//   `- /device       Concrete device cert directory |device|.
	//   |  `- cert.pem
	//   |  `- key.pem
	//   `- cert.pem
	//   `- key.pem

	// Device:
	deviceTLS, err := NewTLSConfig(path.Join(currentDir, "device"))
	if err != nil {
		panic(err)
	}

	device, err := NewClentSession(
		serverURL, deviceTLS, "Test_Client_device")
	if err != nil {
		panic(err)
	}
	defer device.Disconnect()

	if err := device.Subscribe(topicBaseName + "/commands"); err != nil {
		panic(err)
	}

	// Registry:
	registryTLS, err := NewTLSConfig(currentDir)
	if err != nil {
		panic(err)
	}

	registry, err := NewClentSession(
		serverURL, registryTLS, "Test_Client_registry")
	if err != nil {
		panic(err)
	}
	defer registry.Disconnect()

	if err := registry.Subscribe(topicBaseName + "/events"); err != nil {
		panic(err)
	}
	// Device publish event and listen command:
	if err := device.Publish(topicBaseName+"/events", "Some event"); err != nil {
		panic(err)
	}
	// Registry publish command and listen event:
	if err := registry.Publish(topicBaseName+"/commands", "Some command"); err != nil {
		panic(err)
	}

	receivedEvent := <-registry.GetMessages()
	receivedCommand := <-device.GetMessages()
	fmt.Println("Received command: ", receivedCommand)
	fmt.Println("Received event: ", receivedEvent)
}
