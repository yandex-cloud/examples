using System;
using System.Threading;

namespace YandexIoTCoreExample
{
  class Program
  {
    private const string DeviceID = "<your device id>";

    private const bool useCerts = true; // change it if login-password authentication is used

    // used for certificate authentication
    private const string RegistryCertFileName = "<your registry cert file name>";
    private const string DeviceCertFileName = "<your device cert file name>";

    // used for login-password authentication
    private const string RegistryID = "<your registry id>";
    private const string RegistryPassword = "<your registry password>";
    private const string DevicePassword = "<your device password>";

    private static ManualResetEvent oSubscibedData = new ManualResetEvent(false);

    static void Main(string[] args)
    {
      string topic = YaClient.TopicName(DeviceID, EntityType.Device, TopicType.Events);

      using (YaClient regClient = new YaClient(), devClient = new YaClient())
      {
        if (useCerts) {
          regClient.Start(RegistryCertFileName);
          devClient.Start(DeviceCertFileName);
        } else {
          regClient.Start(RegistryID, RegistryPassword);
          devClient.Start(DeviceID, DevicePassword);
        }

        if (!regClient.WaitConnected() || !devClient.WaitConnected())
        {
          return;
        }
        regClient.SubscribedData += DataHandler;
        regClient.Subscribe(topic, MQTTnet.Protocol.MqttQualityOfServiceLevel.AtLeastOnce).Wait();

        devClient.Publish(topic, "test data", MQTTnet.Protocol.MqttQualityOfServiceLevel.AtLeastOnce).Wait();
        Console.WriteLine($"Published data to: {topic}");

        oSubscibedData.WaitOne();
      }
    }

    private static void DataHandler(string topic, byte[] payload)
    {
      var Payload = System.Text.Encoding.UTF8.GetString(payload);
      Console.WriteLine($"Received data: {topic}:\t{Payload}");
      oSubscibedData.Set();
    }
  }
}
