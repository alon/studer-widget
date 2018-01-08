'use strict';


function parse_csv(data)
{
    var lines = data.split('\n');
    var header = lines[0].split(',');
    // lines 1 and 2 are not important
    var extra_header = lines.slice(1, 3);
    var cells = lines.slice(3).map(function (line) { return line.split(','); });
    var n = cells[0].length;
    var last = 0;
    // remove trailing lines - they contain different information
    for (var i = cells.length - 1; i > 0; --i) {
        var cur = cells[i].length;
        if (cur === n)
        {
            last = i + 1;
            break;
        }
    }
    var trailer = cells.slice(last);
    cells = cells.slice(0, last);
    // must be a oneliner somewhere to do this
    var ret = {};
    // skip first cell - it is just the version
    var titles = ['time'].concat(header.slice(1));
    for (var i in titles) {
        var title = titles[i];
        var col = cells.map(function (row) { return row[i]; });
        ret[title] = col;
    }
    // TODO: convert time to Date objects (by parsing)
    ret.csv_version = header[0];
    ret.titles = titles;
    ret.extra_header = extra_header;
    ret.trailer = trailer;
    return ret;
}

function csv_date(timestr)
{
    var date = timestr.split(' ')[0].split('.');
    var year = date[2];
    var month = date[1];
    var day = date[0];
    return new Date(Date.UTC(year, month - 1, day, 0, 0, 0)); // month is 0 based
}


function merge_csv(csvs)
{
    // Note: ignores csv_version, extra_header, trailer
    var sorted = csvs.map((c, i) => [csv_date(c.time[0]), i]).sort((a, b) => a[0].getTime() > b[0].getTime()).map(d => csvs[d[1]]);
    var ret = sorted[0];
    for (var i = 1 ; i < sorted.length ; ++i)
    {
        var other = sorted[i];
        for (var it = 0 ; it < ret.titles.length ; ++it)
        {
            var title = ret.titles[it];
            ret[title] = ret[title].concat(other[title]);
        }
    }
    return ret;
}


function decimate_first_of(data, count)
{
    var ret = [];
    for (var i = 0 ; i < data.length ; i += count)
    {
        ret.push(data[i]);
    }
    return ret;
}

// assumes data is rounded to <count> chunks, padded with zeros
function average(data, count)
{
    var ret = [];
    for (var i = 0 ; i < data.length ; i += count)
    {
        var sum = 0;
        for (var j = i ; j < i + count ; ++j)
        {
            sum += data[j];
        }
        ret.push(sum / count);
    }
    return ret;
}


function extract_datasets(response, average_num)
{
    //G_Response = response; // for debugging
    var csvs = response.map(res => parse_csv(res.data));
    //G_CSVS = csvs;
    var data = merge_csv(csvs);
    var parts = data.time.map(x => x.split(' '));
    var date_start = parts[0][0];
    var date_end = parts[parts.length - 1][0];
    var time = decimate_first_of(parts.map(p => {
        var day_month_year = p[0].split('.');
        var hour_minute = p[1].split(':');
        return new Date(day_month_year[2] + '-' + day_month_year[1] + '-' + day_month_year[0]
            + 'T' + hour_minute[0] + ':' + hour_minute[1] + ':00.000');
    }), average_num);
    var labels = time;
    // TODO: take 30 (BSP-Ubat [Vdc]) if it is non zero, otherwise take  14 (XT-Ubat [Vdc] - or maybe 1, XT-Ubat (MIN) [Vdc] - ask Elad)
    // TODO: indices are not fixed, use strings to find index
    var bsp_ubat = 30;
    var bsp_ibat = 31;
    var bsp_soc = 32;
    var bsp_tbat = 33;
    var solar_power_all = 34;
    var bsp_battery_power_label = 'BSP Battery Power [kW]';
    var bsp_battery_power = data.titles.length;
    var bsp_ubat_arr = data[data.titles[bsp_ubat]].map(Number.parseFloat);
    var bsp_ubat_min = Math.min.apply(Math, bsp_ubat_arr);
    var bsp_ubat_max = Math.max.apply(Math, bsp_ubat_arr);
    bsp_ubat_arr = average(bsp_ubat_arr, average_num);
    data.titles.push(bsp_battery_power_label);
    var bsp_ibat_arr = data[data.titles[bsp_ibat]];
    data[bsp_battery_power_label] = data[data.titles[bsp_ubat]].map((v, i) => bsp_ibat_arr[i] * v / 1000.0); // units of kW
    // TODO: bsp_soc with right Y axis (percents)
    var bsp_soc_arr = average(data[data.titles[bsp_soc]].map(Number.parseFloat), average_num);
    function add_shared_attrs(vd) {
        return vd.map(d => Object.assign({
                pointRadius: 0,
                borderWidth: 1,
        }, d));
    };

    var datasets_voltage = add_shared_attrs([
        {
            label: data.titles[bsp_ubat],
            borderColor: '#ff0000',
            data: bsp_ubat_arr,
            yAxisID: 'left-y-axis',
        },
        {
            label: data.titles[bsp_soc],
            borderColor: '#00ff00',
            data: bsp_soc_arr,
            yAxisID: 'right-y-axis',
        },
    ]);
    var scales_voltage = {
        yAxes: [{
            id: 'left-y-axis',
            type: 'linear',
            position: 'left',
            ticks: {
                min: bsp_ubat_min,
                max: bsp_ubat_max,
            },
        }, {
            id: 'right-y-axis',
            type: 'linear',
            position: 'right',
        }],
        xAxes: [{
            type: 'time',
            time: {
                unit: 'day',
            }
        }],
    };

    var datasets_power = add_shared_attrs([
        {
            label: data.titles[solar_power_all],
            borderColor: '#0000ff',
            data: average(data[data.titles[solar_power_all]].map(Number.parseFloat), average_num),
            yAxisID: 'left-y-axis',
        },
        {
            label: data.titles[bsp_battery_power],
            borderColor: '#ff00ff',
            data: average(data[data.titles[bsp_battery_power]].map(Number.parseFloat), average_num),
            yAxisID: 'left-y-axis',
        },
        {
            label: data.titles[bsp_tbat],
            borderColor: '#00ffff',
            data: average(data[data.titles[bsp_tbat]].map(Number.parseFloat), average_num),
            yAxisID: 'right-y-axis',
        },
    ]);
    var scales_power = {
        yAxes: [{
            id: 'left-y-axis',
            type: 'linear',
            position: 'left',
        }, {
            id: 'right-y-axis',
            type: 'linear',
            position: 'right',
        }],
        xAxes: [{
            type: 'time',
            time: {
                unit: 'day',
            }
        }],
    };
    return {
        charts: [
            {
                title: "voltage",
                datasets: datasets_voltage,
                scales: scales_voltage,
            },
            {
                title: "power",
                datasets: datasets_power,
                scales: scales_power,
            }
        ],
        labels: labels,
        time: time,
        date_start: date_start,
        date_end: date_end,
        csv_version: data.csv_version,
    };
}


export default extract_datasets;
