const REGISTRY_ID = require("./").REGISTRY_ID;
const SUBTOPIC = require("./").SUBTOPIC
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

function publishToDevice(deviceDataService, deviceId) {

    const timeStamp = ISODateString(new Date());
    const humiditySensorValue = (parseFloat(process.env.TEMPERATURE_SENSOR_VALUE) + Math.random()).toFixed(2);
    const temperatureSensorValue = (parseFloat(process.env.HUMIDITY_SENSOR_VALUE) + Math.random()).toFixed(2);
    const pressureSensorValue = (parseFloat(process.env.PRESSURE_SENSOR_VALUE) + Math.random()).toFixed(2);
    const carbonDioxideSensorValue = (parseFloat(process.env.CARBON_DIOXIDE_SENSOR_VALUE) + Math.random()).toFixed(2);

    console.log(`publish to ${deviceId}`);
    return deviceDataService.publish({
        deviceId: deviceId,
        topic: `$devices/${deviceId}/events/${SUBTOPIC}`,
        ddata: Buffer.from(
            `{
            "DeviceId":"${deviceId}",
            "TimeStamp":"${timeStamp}",
            "Values":[
                {"Type":"Float","Name":"Humidity","Value":"${humiditySensorValue}"},
                {"Type":"Float","Name":"CarbonDioxide","Value":"${carbonDioxideSensorValue}"},
                {"Type":"Bool","Name":"Pressure","Value":"${pressureSensorValue}"},
                {"Type":"Bool","Name":"Temperature","Value":"${temperatureSensorValue}"}
                ]
            }`
            ),
    });
}

async function publishToAllDevicesInRegistry(session, registryId) {
    const deviceService = new DeviceService(session);
    const deviceDataService = new DeviceDataService(session);
 
    const devices = await deviceService.list({ registryId: registryId });
    console.log(`found ${devices.devices.length} devices in registry ${registryId}`);

    await Promise.all(
        devices.devices.map((device) => {
            publishToDevice(deviceDataService, device.id);
        })
    );
    console.log('all messages sent');
}

module.exports.handler = async (event, context) => {
    const session = new Session(context.token);
    await publishToAllDevicesInRegistry(session, REGISTRY_ID);
    return {statusCode: 200};
}
