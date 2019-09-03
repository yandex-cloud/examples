/**
 * Entry-point for Serverless Function.
 *
 * @param event {Object} request payload.
 * @param context {Object} information about current execution context.
 *
 * @return {Promise<Object>} response to be serialized as JSON.
 */
module.exports.handler = async (event, context) => {
    const {version, session, request} = event;

    let text = 'Hello! I\'ll repeat anything you say to me.';
    if (request['original_utterance'].length > 0)
        text = request['original_utterance'];
    return {
        version,
        session,
        response: {
            // Respond with the original request or welcome the user if this is the beginning of the dialog and the request has not yet been made.
            text: text,

            // Don't finish the session after this response.
            end_session: false,
        },
    };
};
