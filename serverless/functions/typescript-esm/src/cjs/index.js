/// <reference path="./package.json" />

exports.handler = async (...args) => {
    const { handler } = await import('../index.js');
    return handler(...args);
}
