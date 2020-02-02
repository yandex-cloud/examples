using System;
using System.Collections.Generic;
using System.Linq;
using System.Net.Security;
using System.Security.Authentication;
using System.Security.Cryptography.X509Certificates;
using System.Threading;
using System.Threading.Tasks;
using MQTTnet;
using MQTTnet.Client;
using MQTTnet.Client.Connecting;
using MQTTnet.Client.Disconnecting;
using MQTTnet.Client.Options;

namespace YandexIoTCoreExample
{
  public enum EntityType
  {
    Registry = 0,
    Device = 1
  }

  public enum TopicType
  {
    Events = 0,
    Commands = 1
  }

  class YaClient
  {
    private static X509Certificate2 rootCrt = new X509Certificate2("rootCA.crt");

    public static string TopicName(string entityId, EntityType entity, TopicType topic)
    {
      string result = (entity == EntityType.Registry) ? "$registries/" : "$devices/";
      result += entityId;
      result += (topic == TopicType.Events) ? "/events" : "/commands";
      return result;
    }

    public delegate void OnSubscribedData(string topic, byte[] payload);
    public event OnSubscribedData SubscribedData;

    private IMqttClient mqttClient = null;
    private ManualResetEvent oCloseEvent = new ManualResetEvent(false);
    private ManualResetEvent oConnectedEvent = new ManualResetEvent(false);

    public void Start(string certPath)
    {
      X509Certificate2 certificate = new X509Certificate2(certPath);
      List<byte[]> certificates = new List<byte[]>();
      certificates.Add(certificate.Export(X509ContentType.SerializedCert));

      //setup connection options
      MqttClientOptionsBuilderTlsParameters tlsOptions = new MqttClientOptionsBuilderTlsParameters
      {
        Certificates = certificates,
        SslProtocol = SslProtocols.Tls12,
        UseTls = true
      };
      tlsOptions.CertificateValidationCallback += CertificateValidationCallback;

      // Create TCP based options using the builder.
      var options = new MqttClientOptionsBuilder()
          .WithClientId($"Test_C#_Client_{Guid.NewGuid()}")
          .WithTcpServer("mqtt.cloud.yandex.net", 8883)
          .WithTls(tlsOptions)
          .WithCleanSession()
          .Build();

      var factory = new MqttFactory();
      mqttClient = factory.CreateMqttClient();

      mqttClient.UseApplicationMessageReceivedHandler(DataHandler);
      mqttClient.UseConnectedHandler(ConnectedHandler);
      mqttClient.UseDisconnectedHandler(DisconnectedHandler);
      Console.WriteLine($"Connecting to mqtt.cloud.yandex.net...");
      mqttClient.ConnectAsync(options, CancellationToken.None);
    }

    public void Start(string id, string password)
    {
      //setup connection options
      MqttClientOptionsBuilderTlsParameters tlsOptions = new MqttClientOptionsBuilderTlsParameters
      {
        SslProtocol = SslProtocols.Tls12,
        UseTls = true
      };
      tlsOptions.CertificateValidationCallback += CertificateValidationCallback;

      // Create TCP based options using the builder.
      var options = new MqttClientOptionsBuilder()
          .WithClientId($"Test_C#_Client_{Guid.NewGuid()}")
          .WithTcpServer("mqtt.cloud.yandex.net", 8883)
          .WithTls(tlsOptions)
          .WithCleanSession()
          .WithCredentials(id, password)
          .Build();

      var factory = new MqttFactory();
      mqttClient = factory.CreateMqttClient();

      mqttClient.UseApplicationMessageReceivedHandler(DataHandler);
      mqttClient.UseConnectedHandler(ConnectedHandler);
      mqttClient.UseDisconnectedHandler(DisconnectedHandler);
      Console.WriteLine($"Connecting to mqtt.cloud.yandex.net...");
      mqttClient.ConnectAsync(options, CancellationToken.None);
    }

    public void Stop()
    {
      oCloseEvent.Set();
      mqttClient.DisconnectAsync();
    }

    public bool WaitConnected()
    {
      WaitHandle[] waites = { oCloseEvent, oConnectedEvent };
      return WaitHandle.WaitAny(waites) == 1;
    }

    public Task Subscribe(string topic)
    {
      return mqttClient.SubscribeAsync(topic);
    }

    public Task Publish(string topic, string payload)
    {
      return mqttClient.PublishAsync(topic, payload, MQTTnet.Protocol.MqttQualityOfServiceLevel.AtLeastOnce);
    }


    private Task ConnectedHandler(MqttClientConnectedEventArgs arg)
    {
      oConnectedEvent.Set();
      return Task.CompletedTask;
    }

    private static Task DisconnectedHandler(MqttClientDisconnectedEventArgs arg)
    {
      Console.WriteLine($"Disconnected mqtt.cloud.yandex.net.");
      return Task.CompletedTask;
    }

    private Task DataHandler(MqttApplicationMessageReceivedEventArgs arg)
    {
      SubscribedData(arg.ApplicationMessage.Topic, arg.ApplicationMessage.Payload);
      return Task.CompletedTask;
    }

    private static bool CertificateValidationCallback(X509Certificate arg1, X509Chain arg2, SslPolicyErrors arg3, IMqttClientOptions arg4)
    {
      try
      {
        if (arg3 == SslPolicyErrors.None)
        {
          return true;
        }

        if (arg3 == SslPolicyErrors.RemoteCertificateChainErrors)
        {
          arg2.ChainPolicy.RevocationMode = X509RevocationMode.NoCheck;
          arg2.ChainPolicy.VerificationFlags = X509VerificationFlags.NoFlag;
          arg2.ChainPolicy.ExtraStore.Add(rootCrt);

          arg2.Build((X509Certificate2)rootCrt);
          var res = arg2.ChainElements.Cast<X509ChainElement>().Any(a => a.Certificate.Thumbprint == rootCrt.Thumbprint);
          return res;
        }
      }
      catch { }

      return false;
    }

  }
}