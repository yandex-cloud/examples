package com.yandex.iot.examples.android;

import java.io.IOException;
import java.net.InetAddress;
import java.net.Socket;
import java.net.UnknownHostException;
import java.security.KeyManagementException;
import java.security.KeyStore;
import java.security.KeyStoreException;
import java.security.NoSuchAlgorithmException;
import java.security.SecureRandom;
import java.security.UnrecoverableKeyException;
import java.security.cert.CertificateException;
import java.security.cert.X509Certificate;
import java.util.ArrayList;
import java.util.Arrays;

import javax.net.ssl.KeyManagerFactory;
import javax.net.ssl.SSLContext;
import javax.net.ssl.TrustManager;
import javax.net.ssl.TrustManagerFactory;
import javax.net.ssl.X509TrustManager;

import javax.net.ssl.SSLSocketFactory;

/**
 * Allows you to trust certificates from additional KeyStores in addition to
 * the default KeyStore
 */
public class AdditionalKeyStoresSSLSocketFactory extends SSLSocketFactory {
    protected SSLContext sslContext = SSLContext.getInstance("TLS");

    public AdditionalKeyStoresSSLSocketFactory(KeyStore clientKeyStore, KeyStore serverKeyStore) throws NoSuchAlgorithmException, KeyManagementException, KeyStoreException, UnrecoverableKeyException {
        super();

        if (clientKeyStore != null) {
            KeyManagerFactory kmf = KeyManagerFactory.getInstance(KeyManagerFactory.getDefaultAlgorithm());
            kmf.init(clientKeyStore, "".toCharArray());
            sslContext.init(kmf.getKeyManagers(), new TrustManager[]{new ClientKeyStoresTrustManager(clientKeyStore, serverKeyStore)}, new SecureRandom());
        } else {
            sslContext.init(null, new TrustManager[]{new ClientKeyStoresTrustManager(serverKeyStore)}, null);
        }
    }

    @Override
    public String[] getDefaultCipherSuites() {
        return sslContext.getSocketFactory().getDefaultCipherSuites();
    }

    @Override
    public String[] getSupportedCipherSuites() {
        return sslContext.getSocketFactory().getSupportedCipherSuites();
    }

    @Override
    public Socket createSocket(Socket socket, String host, int port, boolean autoClose) throws IOException {
        return sslContext.getSocketFactory().createSocket(socket, host, port, autoClose);
    }

    @Override
    public Socket createSocket() throws IOException {
        return sslContext.getSocketFactory().createSocket();
    }

    @Override
    public Socket createSocket(String s, int i) throws IOException, UnknownHostException {
        return sslContext.getSocketFactory().createSocket(s, i);
    }

    @Override
    public Socket createSocket(String s, int i, InetAddress inetAddress, int i1) throws IOException, UnknownHostException {
        return sslContext.getSocketFactory().createSocket(s, i, inetAddress, i1);
    }

    @Override
    public Socket createSocket(InetAddress inetAddress, int i) throws IOException {
        return sslContext.getSocketFactory().createSocket(inetAddress, i);
    }

    @Override
    public Socket createSocket(InetAddress inetAddress, int i, InetAddress inetAddress1, int i1) throws IOException {
        return sslContext.getSocketFactory().createSocket(inetAddress, i, inetAddress1, i1);
    }

    /**
     * Based on http://download.oracle.com/javase/1.5.0/docs/guide/security/jsse/JSSERefGuide.html#X509TrustManager
     */
    public static class ClientKeyStoresTrustManager implements X509TrustManager {

        protected ArrayList<X509TrustManager> x509TrustManagers = new ArrayList<X509TrustManager>();

        protected ClientKeyStoresTrustManager(KeyStore... additionalkeyStores) {
            final ArrayList<TrustManagerFactory> factories = new ArrayList<TrustManagerFactory>();

            try {
                // The default Trustmanager with default keystore
                final TrustManagerFactory original = TrustManagerFactory.getInstance(TrustManagerFactory.getDefaultAlgorithm());
                original.init((KeyStore) null);
                factories.add(original);

                for (KeyStore keyStore : additionalkeyStores) {
                    final TrustManagerFactory additionalCerts = TrustManagerFactory.getInstance(TrustManagerFactory.getDefaultAlgorithm());
                    additionalCerts.init(keyStore);
                    factories.add(additionalCerts);
                }

            } catch (Exception e) {
                throw new RuntimeException(e);
            }

            /*
             * Iterate over the returned trustmanagers, and hold on
             * to any that are X509TrustManagers
             */
            for (TrustManagerFactory tmf : factories)
                for (TrustManager tm : tmf.getTrustManagers())
                    if (tm instanceof X509TrustManager)
                        x509TrustManagers.add((X509TrustManager) tm);

            if (x509TrustManagers.size() == 0)
                throw new RuntimeException("Couldn't find any X509TrustManagers");

        }

        public void checkClientTrusted(X509Certificate[] chain, String authType) throws CertificateException {
            for (X509TrustManager tm : x509TrustManagers) {
                try {
                    tm.checkClientTrusted(chain, authType);
                    return;
                } catch (CertificateException e) {

                }
            }
            throw new CertificateException();
        }

        /*
         * Loop over the trustmanagers until we find one that accepts our server
         */
        public void checkServerTrusted(X509Certificate[] chain, String authType) throws CertificateException {
            for (X509TrustManager tm : x509TrustManagers) {
                try {
                    tm.checkServerTrusted(chain, authType);
                    return;
                } catch (CertificateException e) {

                }
            }
            throw new CertificateException();
        }

        public X509Certificate[] getAcceptedIssuers() {
            final ArrayList<X509Certificate> list = new ArrayList<X509Certificate>();
            for (X509TrustManager tm : x509TrustManagers)
                list.addAll(Arrays.asList(tm.getAcceptedIssuers()));
            return list.toArray(new X509Certificate[list.size()]);
        }
    }

}
