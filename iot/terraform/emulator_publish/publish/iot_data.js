const REGISTRY_ID = require("./").REGISTRY_ID;
const SUBTOPIC = require("./").SUBTOPIC
const {Session} = require("yandex-cloud");
const {FunctionService} = require("yandex-cloud/api/serverless/functions/v1");
const {
    DeviceService,
    DeviceDataService,
} = require("yandex-cloud/api/iot/devices/v1");

function publishToDevice(deviceDataService, deviceId) {
    console.log(`publish to ${deviceId}`);
    return deviceDataService.publish({
        deviceId: deviceId,
        topic: `$devices/${deviceId}/events/${SUBTOPIC}`,
        data: Buffer.from('publish to ${deviceId} from function emulator'),
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
