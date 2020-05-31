## Данный проект показывает пример работы с Yandex Iot Core на платформе Android  
  
  
Пример сделан с использованием Android Studio и библиотеки [Paho для Andoid](https://github.com/eclipse/paho.mqtt.android).  
  
Для работы нужно иметь созданный  [реестр](https://cloud.yandex.ru/docs/iot-core/quickstart#create-registry) и  [устройство](https://cloud.yandex.ru/docs/iot-core/quickstart#create-device).  
  
[Сертификат удостоверяющего  центра](https://storage.yandexcloud.net/mqtt/rootCA.crt) включен в проект в качестве ресурса.  
  
Пример показывает возможность авторизации как с помощью сертификатов, так и с помощью пары логин/пароль, а также демонстрирует отправку и прием данных.  
  
В интерфейсе пользователя приложения:
- Кнопка Connect производит подключение к Yandex IoT Core
- Кнопка Publish отправляет сообщение в топик *publishTopic*
- Поле Received message показывает сообщение, принятое из *subscribeTopic*

Сообщения принимаются и отправляются в кодировке UTF-8
  
#### Сертификаты  
  
Чтобы использовать авторизацию с помощью сертификатов, нужно сделать следуюбщее:  
1) Сгенерировать сертификат в формате PKCS12 из [pem сертификатов](https://cloud.yandex.ru/docs/iot-core/quickstart#create-ca) с помощью команды  

    `openssl pkcs12 -export -in cert.pem -inkey key.pem -out keystore.p12 `
  
2) Заменить в ресурсах файл res/raw/your_cert.p12 на сгенерированный в п.1 сертификат  
3) В файле MainActivity.java указать актуальные [топики](https://cloud.yandex.ru/docs/iot-core/concepts/topic) публикации и подписки  
   
   ```
   private static String publishTopic = "$devices/<device id>/events";
   private static String subscribeTopic = "$devices/<device id>/commands";
   ```
  
По умолчанию, пример использует авторизацию с помощью сертификатов.  
За настройки клиента для автризации с помощью сертификатов отвечает следующий код в MainActivity.java  
  
```
 // Use this to connect using client certificate
 try {  
     sslSocketFactory = getSocketFactory(
     getApplicationContext().getResources().openRawResource(R.raw.root_ca),
     getApplicationContext().getResources().openRawResource(R.raw.your_cert), "");
 } catch (Exception e) {  
  e.printStackTrace();
 }
```

 #### Логин/пароль  
  
тобы использовать авторизацию с помощью пары логин/пароль, нужно сделать следуюбщее:  
1) Нужно сгенерировать пароли для [реестра](https://cloud.yandex.ru/docs/iot-core/operations/password/registry-password) или для [устройства](https://cloud.yandex.ru/docs/iot-core/operations/password/device-password).  
2) В файле MainActivity.java указать актуальные логин или пароль  
   ```
   private static String mqttUserName = "<client username>";
   private static String mqttPassword = "<client password>";
   ```
3) В файле MainActivity.java указать актуальные [топики](https://cloud.yandex.ru/docs/iot-core/concepts/topic) публикации и подписки  
          
   ```
   private static String publishTopic = "$devices/<device id>/events";
   private static String subscribeTopic = "$devices/<device id>/commands";
   ```
      
4) Закомменировать код, отвечающий авторизацию с помощью сертификатов  
  ```
  // Use this to connect using client certificate  
  //   try {  
  //       sslSocketFactory = getSocketFactory(  
  //       getApplicationContext().getResources().openRawResource(R.raw.root_ca),  
  //       getApplicationContext().getResources().openRawResource(R.raw.your_cert), "");  
  //   } catch (Exception e) {  
  //       e.printStackTrace();  
  //   }  
  ```
5) Раскомментировать код, отвечающий за авторизацию с помощью логина/пароля  
  
 ```
 // Use this to connect using username and password  
 options.setUserName(mqttUserName); 
 options.setPassword(mqttPassword.toCharArray());  
 try { sslSocketFactory = getSocketFactory(
      getApplicationContext().getResources().openRawResource(R.raw.root_ca), null, ""); 
 } catch (Exception e) { e.printStackTrace(); }  
 ```
  
  
### Особенности примера.  
  
При переносе кода данного примера в другие проекты, следует обратить внимание на следующие особенности:  
1) Приложению нужно в AndroidManifest.xml дать несколько разрешений:  

   ```
   <uses-permission android:name="android.permission.WAKE_LOCK"/>  
   <uses-permission android:name="android.permission.ACCESS_NETWORK_STATE"/>  
   <uses-permission android:name="android.permission.INTERNET" />  
   ```
   
2) Pacho Android клиент запускает сервис. Это нужно указать в AndroidManifest.xml 
 
   ```
   <service android:name="org.eclipse.paho.android.service.MqttService"/>  
   ```
   
3) В примере класс AdditionslKeyStoresSSLSocketFactory используется для работы с самоподписными сертификатами.