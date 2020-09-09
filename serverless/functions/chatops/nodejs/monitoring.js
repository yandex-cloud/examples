const fetch = require('node-fetch');
const yc = require('yandex-cloud');

/*
 * This is ugly hack to make requests to Yandex Monitoring
 * using linked service account token.
 *
 * Honestly, this piece of code should be placed in `yandex-cloud` packages.
 */

// Implementation
class DataServiceImpl {
    constructor(address, credentials, options, tokenCreator) {
        this._tokenCreator = tokenCreator;
        this.$method_definitions = {};
    }

    // Read timeseries data from Yandex Monitoring
    // @see https://cloud.yandex.ru/docs/monitoring/api-ref/MetricsData/read
    async read(folderId, query, from, to, opts) {
        const dataUrl = `https://monitoring.api.cloud.yandex.net/monitoring/v2/data/read?folderId=${folderId}`
        const dataRequest = {
            "query": query,
            "fromTime": from,
            "toTime": to,
            ...opts,
        };

        const token = await this._tokenCreator();
        const resp = await fetch(dataUrl, {
            method: 'post',
            body: JSON.stringify(dataRequest),
            headers: {
                'Content-Type': 'application/json',
                'Authorization': `Bearer ${token}`,
            },
        });

        return resp.json();
    }
}

// Ugly hack to make it work. Nevermind.
DataServiceImpl.__endpointId = 'endpoint';

// Exported factory.
function DataService(session) {
    if (session === undefined) {
        session = new yc.Session();
    }

    return session.client(DataServiceImpl);
}

module.exports = {
    DataService,
};
