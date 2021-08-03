const yc = require('yandex-cloud');
const { Parser } = require('@robojones/nginx-log-parser')

module.exports.handler = async function(event, context) {
    const schema = '$remote_addr - $remote_user [$time_local] "$request" $status $bytes_sent "$http_referer" "$http_user_agent"'
    const parser = new Parser(schema)
    return { 
        Records: event.Records.map(record => {
            const decodedData = new Buffer(record.kinesis.data, 'base64').toString('ascii').trim();
            try {
                const result = parser.parseLine(decodedData)
                if (result.request == "") { // empty request - drop message
                    return {
                        eventID: record.eventID,
                        invokeIdentityArn: record.invokeIdentityArn,
                        eventVersion: record.eventVersion,
                        eventName: record.eventName,
                        eventSourceARN: record.eventSourceARN,
                        result: 'Dropped'
                    }
                }
                return { // successfully parsed message
                    eventID: record.eventID,
                    invokeIdentityArn: record.invokeIdentityArn,
                    eventVersion: record.eventVersion,
                    eventName: record.eventName,
                    eventSourceARN: record.eventSourceARN,
                    kinesis: {data: new Buffer(JSON.stringify(result)).toString('base64')},
                    result: 'Ok'
                }
            } catch(err) { // error - fail message
                return {
                    eventID: record.eventID,
                    invokeIdentityArn: record.invokeIdentityArn,
                    eventVersion: record.eventVersion,
                    eventName: record.eventName,
                    eventSourceARN: record.eventSourceARN,
                    result: 'ProcessingFailed'
                }
            }
        }),
    };
};