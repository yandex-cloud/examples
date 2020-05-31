Здесь расположены примеры использования terraform для разворачивания в Яндекс.Облаке следующих сценариев:
1. [Эмултрование устройств на базе Yandex Cloud Functions](emulator_publish)
2. [Запись данных от устройств в PostgreSQL на базе Yandex Cloud Functions](subscribe_and_postgresql)

В качестве примера источника данных в сценариях используются данные датчика воздуха, измеряющего следующие параметры:
 - Температура
 - Влажность
 - Давление
 - Уровень содержания СO2

 Датчик выдает результат в формате JSON. Например:

   `{
    "DeviceId":"0e3ce1d0-1504-4325-972f-55c961319814",
    "TimeStamp":"2020-05-21T22:53:16Z",
    "Values":[
        {"Type":"Float","Name":"Humidity","Value":"25.281837"},
        {"Type":"Float","Name":"CarbonDioxide","Value":"67.96608"},
        {"Type":"Float","Name":"Pressure","Value":"110.7021"},
        {"Type":"Float","Name":"Temperature","Value":"127.708824"}
        ]
   `}
