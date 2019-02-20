const zlib = require('zlib');

exports.handler = async (event, context) => {
    const payload = new Buffer(event.awslogs.data, 'base64');
    const parsed = JSON.parse(zlib.gunzipSync(payload).toString('utf8'));
    console.log('Decoded payload:', JSON.stringify(parsed));
    return `Successfully processed ${parsed.logEvents.length} log events.`;
};
