// 'Hello World' nodejs6.10 runtime AWS Lambda function
exports.handler = (event, context, callback) => {
    console.log('Hello World!');
    callback(null, 'Keisha Destroyed');
}
