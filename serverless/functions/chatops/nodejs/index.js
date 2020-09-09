const t = require('telegraf');

const {InstanceService, Instance} = require('yandex-cloud/api/compute/v1');

const {DataService} = require('./monitoring');
const {renderCpuUsage} = require('./chart');

const folderId = process.env.FOLDER_ID;

// Initialize Yandex.Cloud SDK services
const instanceService = new InstanceService();
const dataService = new DataService();

/**
 * Return human readable Instance.Status
 * @param {number} status Number representation of Instance.Status
 * @returns {string} Hyman readable value
 */
function formatInstanceStatus(status) {
    for (let s in Instance.Status) {
        if (status === Instance.Status[s]) {
            return s;
        }
    }
    return 'UNKNOWN';
}

/**
 * Reply with nicely formatted usage.
 * @param ctx {t.Context} request context
 * @returns {Promise<void>}
 */
async function usage(ctx) {
    await ctx.replyWithMarkdown(`Nice to hear from you, ${ctx.message.from.username}! Try \`/list\` to get your instances or \`/cpu <ID>\` to watch nice graphs.`);
}

// Creates new bot instance
const bot = new t.Telegraf(process.env.BOT_TOKEN);

// Error handler. Will log errors to Cloud Functions logs.
bot.catch((err, ctx) => {
    console.error(`Bot Error on ${ctx.updateType}`, err);
});

// Handle /list commands, get instance list from Compute and
// reply with formatted message.
bot.command('list', async (ctx) => {
    const instances = await instanceService.list({folderId});

    let reply = "Here is your instances:\n";
    for (const instance of instances.instances) {
        reply += `\n- ${instance.id}`;
        if (instance.name && instance.name.length > 0) {
            reply += ` (${instance.name})`;
        }
        reply += ` ${formatInstanceStatus(instance.status)}`;
    }

    await ctx.reply(reply);
});

// Handle /cpu command. Accepts `instance_id`, fetches
// CPU Usage from Yandex Monitoring and reply to message
// with rendered chart.
bot.command('cpu', async (ctx) => {
    const commandEntity = ctx.update.message.entities[0];
    const restCommand = ctx.update.message.text
        .substr(commandEntity.offset + commandEntity.length)
        .trim()
        .split(' ');

    if (!restCommand || restCommand.length !== 1) {
        return usage(ctx);
    }

    const cpuData = await dataService.read(
        folderId,
        `cpu_usage{service=\"compute\", resource_id=\"${restCommand[0]}\"}`,
        Date.now() - 24 * 60 * 60 * 1000,
        Date.now(),
        {
            "downsampling": {
                "maxPoints": 24 * 4
            }
        }
    );

    await ctx.replyWithPhoto({
        source: await renderCpuUsage(restCommand[0], cpuData),
    });
});

// Handles any other messages, replies with usage.
bot.on('text', usage);

/**
 * Cloud Functions entrypoint.
 * @param event {object} Request data.
 * @param context {object} Execution context (various information about current function).
 * @returns {Promise<{body: string, statusCode: number}>} Response.
 */
module.exports.handler = async function (event, context) {
    const message = JSON.parse(event.body);
    await bot.handleUpdate(message);
    return {
        statusCode: 200,
        body: '',
    };
};