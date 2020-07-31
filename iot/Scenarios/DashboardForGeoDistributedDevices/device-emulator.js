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

function publishToDevice(deviceDataService, iotCoreDeviceId) {
    
    const timeStamp = ISODateString(new Date());
    const serviceDoorSensorValue = process.env.SERVICE_DOOR_SENSOR_VALUE;
    const powerVoltageSensorValue = (parseFloat(process.env.POWER_SENSOR_VALUE) + Math.random()).toFixed(2);
    const temperatureSensorValue = (parseFloat(process.env.TEMPERATURE_SENSOR_VALUE) + Math.random()).toFixed(2);
    const cashDrawerSensorValue = process.env.CASH_DRAWER_SENSOR_VALUE;

    const item1SensorValue = process.env.ITEM1_SENSOR_VALUE;
    const item2SensorValue = process.env.ITEM2_SENSOR_VALUE;
    const item3SensorValue = process.env.ITEM3_SENSOR_VALUE;
    const item4SensorValue = process.env.ITEM4_SENSOR_VALUE;

    console.log(`publish to ${iotCoreDeviceId}`);

    return deviceDataService.publish({
        deviceId: iotCoreDeviceId,
        topic: `$devices/${iotCoreDeviceId}/events/`,
        data: Buffer.from(
            `{
            "DeviceId":"${iotCoreDeviceId}",
            "TimeStamp":"${timeStamp}",
            "Values":[
                {"Type":"Bool","Name":"Service door sensor","Value":"${serviceDoorSensorValue}"},
                {"Type":"Float","Name":"Power Voltage","Value":"${powerVoltageSensorValue}"},
                {"Type":"Float","Name":"Temperature","Value":"${temperatureSensorValue}"},
                {"Type":"Float","Name":"Cash drawer fullness","Value":"${cashDrawerSensorValue}"},
                {"Items":[
                    {"Type":"Float", "Id":"1","Name":"Item 1","Fullness":"${item1SensorValue}"},
                    {"Type":"Float", "Id":"2","Name":"Item 2","Fullness":"${item2SensorValue}"},
                    {"Type":"Float", "Id":"3","Name":"Item 3","Fullness":"${item3SensorValue}"},
                    {"Type":"Float", "Id":"4","Name":"Item 4","Fullness":"${item4SensorValue}"}
                ]}
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
    await publishToAllDevicesInRegistry(session, process.env.REGISTRY_ID);
    return {statusCode: 200};
}

/* Function result example
{
    "DeviceId":"arealt9f3jh445it1laq",
    "TimeStamp":"2020-06-09T20:41:45Z",
    "Values":[
        {"Type":"Bool","Name":"Service door sensor","Value":"False"},
        {"Type":"Float","Name":"Power Voltage","Value":"24.94"},
        {"Type":"Float","Name":"Temperature","Value":"10.48"},
        {"Type":"Float","Name":"Cash drawer fullness","Value":"67.89"},
        {"Items":[
            {"Type":"Float", "Id":"1","Name":"Item 1","Fullness":"50.65"},
            {"Type":"Float", "Id":"2","Name":"Item 2","Fullness":"80.97"},
            {"Type":"Float", "Id":"3","Name":"Item 3","Fullness":"30.33"},
            {"Type":"Float", "Id":"4","Name":"Item 4","Fullness":"15.15"}
        ]}
        ]
}
*/
