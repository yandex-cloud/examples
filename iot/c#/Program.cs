using System;
using System.Threading;

namespace YandexIoTCoreExample
{
  class Program
  {
    private const string DeviceID = "<your device id>";

    private const bool useCerts = true; // change it if login-password autentification is used

    // used for certificate authentification
    private const string RegistryCertFileName = "<your registry cert file name>";
    private const string DeviceCertFileName = "<your device cert file name>";

    // used for login-password authentification
    private const string RegistryID = "<your registry id>";
    private const string RegistryPassword = "<your registry password>";
    private const string DevicePassword = "<your device password>";

    private static ManualResetEvent oSubscibedData = new ManualResetEvent(false);

    static void Main(string[] args)
    {
      string topic = YaClient.TopicName(DeviceID, EntityType.Device, TopicType.Events);

      YaClient regClient = new YaClient();
      if (useCerts)
        regClient.Start(RegistryCertFileName);
      else
        regClient.Start(RegistryID, RegistryPassword);
      if (!regClient.WaitConnected())
      {
        return;
      }
      regClient.SubscribedData += DataHandler;
      regClient.Subscribe(topic).Wait();

      YaClient devClient = new YaClient();
      if (useCerts)
        devClient.Start(DeviceCertFileName);
      else
        devClient.Start(DeviceID, DevicePassword);
      if (!devClient.WaitConnected())
      {
        return;
      }
      devClient.Publish(topic, "test data").Wait();
      Console.WriteLine($"Published data to: {topic}");

      oSubscibedData.WaitOne();
      regClient.Stop();
      devClient.Stop();
    }

    private static void DataHandler(string topic, byte[] payload)
    {
      var Payload = System.Text.Encoding.UTF8.GetString(payload);
      Console.WriteLine($"Received data: {topic}:\t{Payload}");
      oSubscibedData.Set();
    }
  }
}
