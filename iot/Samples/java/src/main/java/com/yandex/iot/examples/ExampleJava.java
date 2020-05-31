package com.yandex.iot.examples;

import java.io.ByteArrayInputStream;
import java.io.FileInputStream;
import java.io.InputStream;
import java.nio.charset.StandardCharsets;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.security.cert.CertificateFactory;
import java.security.cert.X509Certificate;
import java.security.KeyStore;
import java.util.concurrent.CountDownLatch;
import javax.net.ssl.KeyManagerFactory;
import javax.net.ssl.SSLContext;
import javax.net.ssl.SSLSocketFactory;
import javax.net.ssl.TrustManagerFactory;

import org.eclipse.paho.client.mqttv3.IMqttDeliveryToken;
import org.eclipse.paho.client.mqttv3.MqttCallback;
import org.eclipse.paho.client.mqttv3.MqttClient;
import org.eclipse.paho.client.mqttv3.MqttConnectOptions;
import org.eclipse.paho.client.mqttv3.MqttException;
import org.eclipse.paho.client.mqttv3.MqttMessage;


public class ExampleJava {
    private final String brokerURL = "ssl://mqtt.cloud.yandex.net:8883";
    private final String deviceID = "<insert device id>";

    // Needed only for login with password:
    private final String devicePassword = "<insert device password>";
    private final String registryID = "<insert registry id>";
    private final String regPassword = "<insert registry password>";

    private final String deviceEvents = "$devices/" + deviceID + "/events";
    private final String deviceCommands = "$devices/" + deviceID + "/commands";

    // See https://www.eclipse.org/paho/files/mqttdoc/MQTTClient/html/qos.html
    public enum QoS {
        AT_MOST_ONCE(0),
        AT_LEAST_ONCE(1);

        private final int value;

        private QoS(int value) {
            this.value = value;
        }

        public int getValue() {
            return value;
        }
    }

    private static final String TRUSTED_ROOT = "-----BEGIN CERTIFICATE-----\n" +
            "MIIFGTCCAwGgAwIBAgIQJMM7ZIy2SYxCBgK7WcFwnjANBgkqhkiG9w0BAQ0FADAf\n" +
            "MR0wGwYDVQQDExRZYW5kZXhJbnRlcm5hbFJvb3RDQTAeFw0xMzAyMTExMzQxNDNa\n" +
            "Fw0zMzAyMTExMzUxNDJaMB8xHTAbBgNVBAMTFFlhbmRleEludGVybmFsUm9vdENB\n" +
            "MIICIjANBgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEAgb4xoQjBQ7oEFk8EHVGy\n" +
            "1pDEmPWw0Wgw5nX9RM7LL2xQWyUuEq+Lf9Dgh+O725aZ9+SO2oEs47DHHt81/fne\n" +
            "5N6xOftRrCpy8hGtUR/A3bvjnQgjs+zdXvcO9cTuuzzPTFSts/iZATZsAruiepMx\n" +
            "SGj9S1fGwvYws/yiXWNoNBz4Tu1Tlp0g+5fp/ADjnxc6DqNk6w01mJRDbx+6rlBO\n" +
            "aIH2tQmJXDVoFdrhmBK9qOfjxWlIYGy83TnrvdXwi5mKTMtpEREMgyNLX75UjpvO\n" +
            "NkZgBvEXPQq+g91wBGsWIE2sYlguXiBniQgAJOyRuSdTxcJoG8tZkLDPRi5RouWY\n" +
            "gxXr13edn1TRDGco2hkdtSUBlajBMSvAq+H0hkslzWD/R+BXkn9dh0/DFnxVt4XU\n" +
            "5JbFyd/sKV/rF4Vygfw9ssh1ZIWdqkfZ2QXOZ2gH4AEeoN/9vEfUPwqPVzL0XEZK\n" +
            "r4s2WjU9mE5tHrVsQOZ80wnvYHYi2JHbl0hr5ghs4RIyJwx6LEEnj2tzMFec4f7o\n" +
            "dQeSsZpgRJmpvpAfRTxhIRjZBrKxnMytedAkUPguBQwjVCn7+EaKiJfpu42JG8Mm\n" +
            "+/dHi+Q9Tc+0tX5pKOIpQMlMxMHw8MfPmUjC3AAd9lsmCtuybYoeN2IRdbzzchJ8\n" +
            "l1ZuoI3gH7pcIeElfVSqSBkCAwEAAaNRME8wCwYDVR0PBAQDAgGGMA8GA1UdEwEB\n" +
            "/wQFMAMBAf8wHQYDVR0OBBYEFKu5xf+h7+ZTHTM5IoTRdtQ3Ti1qMBAGCSsGAQQB\n" +
            "gjcVAQQDAgEAMA0GCSqGSIb3DQEBDQUAA4ICAQAVpyJ1qLjqRLC34F1UXkC3vxpO\n" +
            "nV6WgzpzA+DUNog4Y6RhTnh0Bsir+I+FTl0zFCm7JpT/3NP9VjfEitMkHehmHhQK\n" +
            "c7cIBZSF62K477OTvLz+9ku2O/bGTtYv9fAvR4BmzFfyPDoAKOjJSghD1p/7El+1\n" +
            "eSjvcUBzLnBUtxO/iYXRNo7B3+1qo4F5Hz7rPRLI0UWW/0UAfVCO2fFtyF6C1iEY\n" +
            "/q0Ldbf3YIaMkf2WgGhnX9yH/8OiIij2r0LVNHS811apyycjep8y/NkG4q1Z9jEi\n" +
            "VEX3P6NEL8dWtXQlvlNGMcfDT3lmB+tS32CPEUwce/Ble646rukbERRwFfxXojpf\n" +
            "C6ium+LtJc7qnK6ygnYF4D6mz4H+3WaxJd1S1hGQxOb/3WVw63tZFnN62F6/nc5g\n" +
            "6T44Yb7ND6y3nVcygLpbQsws6HsjX65CoSjrrPn0YhKxNBscF7M7tLTW/5LK9uhk\n" +
            "yjRCkJ0YagpeLxfV1l1ZJZaTPZvY9+ylHnWHhzlq0FzcrooSSsp4i44DB2K7O2ID\n" +
            "87leymZkKUY6PMDa4GkDJx0dG4UXDhRETMf+NkYgtLJ+UIzMNskwVDcxO4kVL+Hi\n" +
            "Pj78bnC5yCw8P5YylR45LdxLzLO68unoXOyFz1etGXzszw8lJI9LNubYxk77mK8H\n" +
            "LpuQKbSbIERsmR+QqQ==\n" +
            "-----END CERTIFICATE-----";

    private MqttSession registry;
    private MqttSession device;

    public class MqttSession implements MqttCallback {
        private MqttClient client;
        private String clientId;
        private Runnable onDoneHandler;
        private QoS messageQos = QoS.AT_LEAST_ONCE;

        @Override
        public void connectionLost(Throwable cause) {
            System.out.println("connectionLost");
        }

        @Override
        public void messageArrived(String topic, MqttMessage message)
                throws Exception {
            System.out.println(clientId + "> " + topic + ": " + message);
            onDoneHandler.run();
        }

        @Override
        public void deliveryComplete(IMqttDeliveryToken token) {
            System.out.println("deliveryComplete");
        }

        public void Publish(String topic, String payload) throws MqttException {
            MqttMessage msg = new MqttMessage(payload.getBytes());
            msg.setQos(messageQos.getValue());
            client.publish(topic, msg);
        }

        public void Subscribe(String topic) throws MqttException {
            client.subscribe(topic, messageQos.getValue());
        }

        public void Stop() throws MqttException {
            client.disconnect();
            client.close();
        }

        public void Start(String broker, String id, String certsDir)
                throws Exception {
            clientId = id;
            client = new MqttClient(broker, clientId);
            client.setCallback(this);
            MqttConnectOptions connOpts = new MqttConnectOptions();
            connOpts.setSocketFactory(getSocketFactoryWithCerts(certsDir));
            connOpts.setCleanSession(true);
            connOpts.setKeepAliveInterval(60); // Seconds.
            connOpts.setConnectionTimeout(60); // Seconds.
            client.connect(connOpts);
        }

        public void StartWithLogin(String broker, String id, String login, String password)
                throws Exception {
            clientId = id;
            client = new MqttClient(broker, clientId);

            client.setCallback(this);
            MqttConnectOptions connOpts = new MqttConnectOptions();
            connOpts.setSocketFactory(getSocketFactory());
            connOpts.setCleanSession(true);
            connOpts.setKeepAliveInterval(60); // Seconds.
            connOpts.setConnectionTimeout(60); // Seconds.
            connOpts.setUserName(login.trim());
            connOpts.setPassword(password.trim().toCharArray());
            client.connect(connOpts);
        }

        private SSLSocketFactory getSocketFactory()
                throws Exception {
            InputStream is = new ByteArrayInputStream(TRUSTED_ROOT.getBytes(StandardCharsets.UTF_8));
            CertificateFactory cFactory = CertificateFactory.getInstance("X.509");
            X509Certificate caCert = (X509Certificate) cFactory.generateCertificate(
                    is);

            TrustManagerFactory tmf = TrustManagerFactory
                    .getInstance(TrustManagerFactory.getDefaultAlgorithm());
            KeyStore tks = KeyStore.getInstance(KeyStore.getDefaultType());
            tks.load(null); // You don't need the KeyStore instance to come from a file.
            tks.setCertificateEntry("caCert", caCert);
            tmf.init(tks);

            SSLContext ctx = SSLContext.getInstance("TLS");
            ctx.init(null, tmf.getTrustManagers(), null);
            return ctx.getSocketFactory();
        }

        private SSLSocketFactory getSocketFactoryWithCerts(String certsDir)
                throws Exception {
            // Client key/cert:
            final char[] empty = "".toCharArray();
            KeyStore ks = KeyStore.getInstance("PKCS12");
            // To obtain |.p12| from |.pem|:
            // openssl pkcs12 -export -in cert.pem -inkey key.pem -out keystore.p12
            ks.load(new FileInputStream(
                            Paths.get(certsDir, "keystore.p12").toString()),
                    empty);
            KeyManagerFactory kmf = KeyManagerFactory.getInstance("SunX509");
            kmf.init(ks, empty);

            InputStream is = new ByteArrayInputStream(TRUSTED_ROOT.getBytes(StandardCharsets.UTF_8));
            CertificateFactory cFactory = CertificateFactory.getInstance("X.509");
            X509Certificate caCert = (X509Certificate) cFactory.generateCertificate(
                    is);

            TrustManagerFactory tmf = TrustManagerFactory
                    .getInstance(TrustManagerFactory.getDefaultAlgorithm());
            KeyStore tks = KeyStore.getInstance(KeyStore.getDefaultType());
            tks.load(null); // You don't need the KeyStore instance to come from a file.
            tks.setCertificateEntry("caCert", caCert);
            tmf.init(tks);

            SSLContext ctx = SSLContext.getInstance("TLS");
            ctx.init(kmf.getKeyManagers(), tmf.getTrustManagers(), null);
            return ctx.getSocketFactory();
        }

        public void SetOnDoneHandler(Runnable onDone) {
            onDoneHandler = onDone;
        }

        public void SetQOS(QoS value) {
            messageQos = value;
        }
    }

    private void Run(boolean withLogin) {
        try {
            // certs structure:
            //   /my_registry        Registry directory |currentDir|.
            //   `- /device          Concrete device cert directory |device|.
            //   |  `- cert.pem
            //   |  `- key.pem
            //   |  `- keystore.p12  device certs pair in java friendly format
            //   `- cert.pem
            //   `- key.pem
            //   `- keystore.p12     registry certs pair in java friendly format
            String currentDir = System.getProperty("user.dir");

            CountDownLatch cdl = new CountDownLatch(2);

            device = new MqttSession();
            if (withLogin) {
                device.StartWithLogin(brokerURL, "deviceJavaSmpleLogin", deviceID,
                        devicePassword);
            } else {
                device.Start(brokerURL, "deviceJavaSmple",
                        Paths.get(currentDir, "device").toString());
            }

            device.SetOnDoneHandler(cdl::countDown);

            registry = new MqttSession();
            if (withLogin) {
                registry.StartWithLogin(brokerURL, "registyJavaSmpleLogin",
                        registryID, regPassword);
            } else {
                registry.Start(brokerURL, "registyJavaSmple", currentDir.toString());
            }
            registry.SetOnDoneHandler(cdl::countDown);

            registry.Subscribe(deviceEvents);
            device.Subscribe(deviceCommands);

            registry.Publish(deviceCommands, "somecommand");
            device.Publish(deviceEvents, "someevent");

            cdl.await();
            registry.Stop();
            device.Stop();
            return;
        } catch (MqttException me) {
            me.printStackTrace();
        } catch (Exception e) {
            e.printStackTrace();
        }
        System.exit(100);
    }

    public static void main(String[] args) {
        // $ cd <certs dir>
        // $ mvn exec:java -f <.pom path>
        System.out.println("\n\nWith certificate:");
        new ExampleJava().Run(false);
        System.out.println("\n\nWith login:");
        new ExampleJava().Run(true);
    }
}
