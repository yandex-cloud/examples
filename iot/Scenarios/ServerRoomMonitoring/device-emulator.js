const {Session} = require("yandex-cloud");
const {FunctionService} = require("yandex-cloud/api/serverless/functions/v1");
const {
    DeviceService,
    DeviceDataService,
} = require("yandex-cloud/api/iot/devices/v1");

function ISODateString(d){
 function pad(n){return n<10 ? '0'+n : n}
 return d.getUTCFullYear()+'-'
      + pad(d.getMonth()+1)+'-'
      + pad(d.getDate())+'T'
      + pad(d.getHours())+':'
      + pad(d.getMinutes())+':'
      + pad(d.getSeconds())+'Z'}

function publishToDevice(deviceDataService) {

    const deviceId = process.env.DEVICE_ID;
    const timeStamp = ISODateString(new Date());
    const humiditySensorValue = (parseFloat(process.env.HUMIDITY_SENSOR_VALUE) + Math.random()).toFixed(2);
    const temperatureSensorValue = (parseFloat(process.env.TEMPERATURE_SENSOR_VALUE) + Math.random()).toFixed(2);
    const waterSensorValue = process.env.WATER_SENSOR_VALUE;
    const smokeSensorValue = process.env.SMOKE_SENSOR_VALUE;
    const roomDoorSensorValue = process.env.ROOM_DOOR_SENSOR_VALUE;
    const rackDoorSensorValue = process.env.RACK_DOOR_SENSOR_VALUE;

    const iotCoreDeviceId = process.env.IOT_CORE_DEVICE_ID;

    console.log(`publish to ${iotCoreDeviceId}`);

    return deviceDataService.publish({
        deviceId: iotCoreDeviceId,
        topic: `$devices/${iotCoreDeviceId}/events`,
        data: Buffer.from(
            `{
            "DeviceId":"${deviceId}",
            "TimeStamp":"${timeStamp}",
            "Values":[
                {"Type":"Float","Name":"Humidity","Value":"${humiditySensorValue}"},
                {"Type":"Float","Name":"Temperature","Value":"${temperatureSensorValue}"},
                {"Type":"Bool","Name":"Water sensor","Value":"${waterSensorValue}"},
                {"Type":"Bool","Name":"Smoke sensor","Value":"${smokeSensorValue}"},
                {"Type":"Bool","Name":"Room door sensor","Value":"${roomDoorSensorValue}"},
                {"Type":"Bool","Name":"Rack door sensor","Value":"${rackDoorSensorValue}"}
                ]
            }`
            ),
    });
}

module.exports.handler = async (event, context) => {
    const session = new Session(context.token);
    const deviceDataService = new DeviceDataService(session);
    await publishToDevice(deviceDataService);
    return {statusCode: 200};
}

/* Function result example

{
    "DeviceId":"0e3ce1d0-1504-4325-972f-55c961319814",
    "TimeStamp":"2020-05-21T22:53:16Z",
    "Values":[
        {"Type":"Float","Name":"Humidity","Value":"26.05"},
        {"Type":"Float","Name":"Temperature","Value":"80.78"},
        {"Type":"Bool","Name":"Water sensor","Value":"False"},
        {"Type":"Bool","Name":"Smoke sensor","Value":"False"},
        {"Type":"Bool","Name":"Room door sensor","Value":"False"},
        {"Type":"Bool","Name":"Rack door sensor","Value":"False"}
        ]
}

*/
