package com.yandex.iot.examples.android;

import android.os.Bundle;

import org.eclipse.paho.android.service.MqttAndroidClient;
import org.eclipse.paho.android.service.MqttTraceHandler;
import org.eclipse.paho.client.mqttv3.IMqttActionListener;
import org.eclipse.paho.client.mqttv3.IMqttDeliveryToken;
import org.eclipse.paho.client.mqttv3.IMqttToken;
import org.eclipse.paho.client.mqttv3.MqttCallback;
import org.eclipse.paho.client.mqttv3.MqttConnectOptions;
import org.eclipse.paho.client.mqttv3.MqttException;
import org.eclipse.paho.client.mqttv3.MqttMessage;

import androidx.appcompat.app.AppCompatActivity;

import android.util.Log;
import android.view.View;
import android.widget.Button;
import android.widget.TextView;

import com.google.android.material.textfield.TextInputEditText;

import java.io.InputStream;
import java.security.KeyStore;
import java.security.cert.CertificateFactory;
import java.security.cert.X509Certificate;

import javax.net.ssl.SSLSocketFactory;
import javax.net.ssl.TrustManagerFactory;

public class MainActivity extends AppCompatActivity {

    private MqttAndroidClient mqttAndroidClient;
    private static String serverUri = "ssl://mqtt.cloud.yandex.net:8883";
    private static String TAG = "Yandex IoTCore Demo";
    private static final String clientId = "YandexIoTCoreAndroidTextClient";
    private static String publishTopic = "$devices/<device id>/events";
    private static String subscribeTopic = "$devices/<device id>/commands";
    private static String mqttUserName = "<client username>";
    private static String mqttPassword = "<client password>";
    private static final int connectionTimeout = 60;
    private static final int keepAliveInterval = 60;


    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_main);
    }

    private SSLSocketFactory getSocketFactory(final InputStream caCrtFile,
                                              final InputStream devCert, final String password) throws Exception {

        // Load CA certificate
        CertificateFactory cf = CertificateFactory.getInstance("X.509");
        X509Certificate caCert = (X509Certificate) cf.generateCertificate(caCrtFile);

        // CA certificate is used to authenticate server
        KeyStore serverCaKeyStore = KeyStore.getInstance(KeyStore.getDefaultType());
        serverCaKeyStore.load(null, null);
        serverCaKeyStore.setCertificateEntry("ca", caCert);
        TrustManagerFactory tmf = TrustManagerFactory.getInstance(TrustManagerFactory.getDefaultAlgorithm());
        tmf.init(serverCaKeyStore);


        if (devCert != null) {
            KeyStore clientKeystore = KeyStore.getInstance("PKCS12");
            // Load client cert from PKCS#12 resource file
            // To obtain |.p12| from |.pem|:
            // openssl pkcs12 -export -in cert.pem -inkey key.pem -out keystore.p12
            clientKeystore.load(devCert, password.toCharArray());
            return new AdditionalKeyStoresSSLSocketFactory(clientKeystore, serverCaKeyStore);
        }

        return new AdditionalKeyStoresSSLSocketFactory(null, serverCaKeyStore);
    }

    public void onClickPublish(View v) throws MqttException {

        TextInputEditText editText = findViewById(R.id.PublishTextInput);
        if (editText.getText() != null) {
            String msg = editText.getText().toString();
            Log.i(TAG, "Publishing message: " + msg);
            mqttAndroidClient.publish(publishTopic, new MqttMessage(msg.getBytes()));
        }
    }

    public void onClickConnect(View v) throws MqttException {

        // Create mqttClient
        mqttAndroidClient = new MqttAndroidClient(getApplicationContext(), serverUri, clientId);

        // Configure connection options
        MqttConnectOptions options = new MqttConnectOptions();
        options.setConnectionTimeout(connectionTimeout);
        options.setKeepAliveInterval(keepAliveInterval);

        SSLSocketFactory sslSocketFactory = null;

        // Use this to connect using client certificate

        try {
            sslSocketFactory = getSocketFactory(
                    getApplicationContext().getResources().openRawResource(R.raw.root_ca),
                    getApplicationContext().getResources().openRawResource(R.raw.your_cert), "");
        } catch (Exception e) {
            e.printStackTrace();
        }


        // Use this to connect using username and password

//        options.setUserName(mqttUserName);
//        options.setPassword(mqttPassword.toCharArray());
//
//        try {
//            sslSocketFactory = getSocketFactory(
//                    getApplicationContext().getResources().openRawResource(R.raw.root_ca),
//                    null, "");
//        } catch (Exception e) {
//            e.printStackTrace();
//        }


        options.setSocketFactory(sslSocketFactory);

        // Enable mqtt client trace
        mqttAndroidClient.setTraceEnabled(true);
        mqttAndroidClient.setTraceCallback(new MqttTraceHandler() {
            @Override
            public void traceDebug(String tag, String message) {
                Log.d(tag, message);
            }

            @Override
            public void traceError(String tag, String message) {
                Log.e(tag, message);
            }

            @Override
            public void traceException(String tag, String message, Exception e) {
                Log.e(tag, message);
            }
        });

        // Set mqtt client callbacks
        mqttAndroidClient.setCallback(new MqttCallback() {
            @Override
            public void connectionLost(Throwable cause) {
                Log.i(TAG, "Connection lost: " + cause.getMessage());
            }

            @Override
            public void messageArrived(String topic, MqttMessage message) throws Exception {
                TextView textView = findViewById(R.id.receivedTextView2);
                String str = new String(message.getPayload(), "UTF-8");
                textView.setText(str);
                Log.i(TAG, "Received new message: " + str);
            }

            @Override
            public void deliveryComplete(IMqttDeliveryToken token) {
                Log.i(TAG, "Delivery complete");
            }
        });


        // Connect to the server
        Log.i(TAG, "Starting connect the server...");

        mqttAndroidClient.connect(options, null, new IMqttActionListener() {
            @Override
            public void onSuccess(IMqttToken asyncActionToken) {

                Log.i(TAG, "Connected");

                int qos = 1;

                IMqttToken subToken = null;

                Log.i(TAG, "Subscribe to " + subscribeTopic);
                // Subscribe in case off success connection
                try {
                    subToken = mqttAndroidClient.subscribe(subscribeTopic, qos);

                    subToken.setActionCallback(new IMqttActionListener() {
                        @Override
                        public void onSuccess(IMqttToken asyncActionToken) {
                            Log.i(TAG, "Subscribe complete");
                        }

                        @Override
                        public void onFailure(IMqttToken asyncActionToken,
                                              Throwable exception) {
                            // The subscription could not be performed, maybe the user was not
                            // authorized to subscribe on the specified topic e.g. using wildcards
                            Log.i(TAG, "Failed to subscribe to: " + subscribeTopic + " " + exception.getMessage());

                        }
                    });

                } catch (MqttException e) {
                    e.printStackTrace();
                }

                // Disable connect button and enable publish controls
                Button buttonPublish = findViewById(R.id.buttonPublish);
                Button buttonConnect = findViewById(R.id.buttonConnect);
                TextInputEditText editText = findViewById(R.id.PublishTextInput);

                buttonConnect.setEnabled(false);
                buttonPublish.setEnabled(true);
                editText.setEnabled(true);
            }

            @Override
            public void onFailure(IMqttToken asyncActionToken, Throwable exception) {
                Log.i(TAG, "Failed to connect to " + serverUri + " " + exception.getMessage());
            }
        });
    }
}
