const {CanvasRenderService} = require('chartjs-node-canvas');

/**
 * Render simple chart and returns buffer
 */
async function renderCpuUsage(instanceId, data) {
    const canvasRenderService = new CanvasRenderService(1440, 900, (ChartJS) => {
        ChartJS.defaults.global.elements.rectangle.borderWidth = 1;
    });

    let dataPoints = [];
    for (let i = 0; i < data.metrics[0].timeseries.timestamps.length; i++) {
        dataPoints.push({
            x: data.metrics[0].timeseries.timestamps[i],
            y: data.metrics[0].timeseries.doubleValues[i],
        });
    }

    const chrt = {
        type: 'line',
        data: {
            datasets: [{
                label: instanceId,
                data: dataPoints,
                borderColor: 'rgba(82, 130, 255, 0.8)',
                backgroundColor: 'rgba(82, 130, 255, 0.3)',
                borderWidth: 1,
                radius: 0,
            }]
        },
        options: {
            responsive: true,
            title: {
                display: true,
                text: 'CPU Usage'
            },
            legend: {
                labels: {
                    fontColor: 'black'
                }
            },
            scales: {
                xAxes: [{
                    type: 'time',
                    display: true,
                    time: {
                        unit: 'hour'
                    }
                }],
            }
        }
    };

    return await canvasRenderService.renderToBuffer(chrt);
}

module.exports = {
    renderCpuUsage,
};