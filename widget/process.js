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


function replace_high(c, rep)
{
    if (c.charCodeAt(0) >= 65533)
    {
        return rep;
    }
    return c;
}

/**
 * Studer headers reference:

XT-Ubat- (MIN) [Vdc]
XT-Uin [Vac]
XT-Iin [Aac]
XT-Pout [kVA]
XT-Pout+ [kVA]
XT-Fout [Hz]
XT-Fin [Hz]
XT-Phase []
XT-Mode []
XT-Transfert []
XT-RME []
XT-Aux 1 []
XT-Aux 2 []
XT-Ubat [Vdc]
XT-Ibat [Adc]
XT-Pin a [kW]
XT-Pout a [kW]
XT-Dev1+ (MAX) []

VT-PsoM [kW]
VT-Mode []
VT-Dev1 []
VT-UpvM [Vdc]
VT-IbaM [Adc]
VT-UbaM [Vdc]
VT-Phas []
VT-RME []
VT-Aux 1 []
VT-Aux 2 []

BSP-Ubat [Vdc]
BSP-Ibat [Adc]
BSP-SOC [%]
BSP-Tbat [<B0>C]

Solar power (ALL) [kW]

DEV XT-DBG1 []
DEV VT-locEr []
DEV SYS MSG
DEV SYS SCOM ERR
 */

function extract_datasets(response, average_num)
{
    var csvs = response.map(res => parse_csv(res.data));
    var data = merge_csv(csvs);
    var parts = data.time.map(x => x.split(' '));
    var date_start = parts[0][0];
    var date_end = parts[parts.length - 1][0];
    var time_full = parts.map(p => {
        var day_month_year = p[0].split('.');
        var hour_minute = p[1].split(':');
        return new Date(day_month_year[2] + '-' + day_month_year[1] + '-' + day_month_year[0]
            + 'T' + hour_minute[0] + ':' + hour_minute[1] + ':00.000');
    });
    var time = decimate_first_of(time_full, average_num);
    var labels = time;
    var titles = data.titles;
    function indexof(s) {
        for (var i = 0 ; i < titles.length ; ++i)
        {
            if (titles[i].substr(0, s.length) == s) { return i; }
        }
        console.error('could not find ' + s + ' in titles: ' + titles);
        return 0;
    }
    var xt_ubat = indexof('XT-Ubat');
    var xt_ibat = indexof('XT-Ibat');
    var xt_pin = indexof('XT-Pin');
    var xt_pout = indexof('XT-Pout');
    var bsp_ubat = indexof('BSP-Ubat');
    var bsp_ibat = indexof('BSP-Ibat');
    var bsp_soc = indexof('BSP-SOC');
    var bsp_tbat = indexof('BSP-Tbat');
    var solar_power_all = indexof('Solar power (ALL)');

    var tofloat_avg = title => average(data[title].map(Number.parseFloat), average_num);

    var xt_ubat_arr = tofloat_avg(data.titles[xt_ubat]);
    var xt_pin_title = data.titles[xt_pin];
    var xt_pout_title = data.titles[xt_pout];
    var xt_pin_arr = tofloat_avg(xt_pin_title);
    var xt_pout_arr = tofloat_avg(xt_pout_title);
    var bsp_battery_power_title = 'BSP Battery Power [kW]';
    var bsp_battery_power = data.titles.length;
    var bsp_ubat_arr = data[data.titles[bsp_ubat]].map(Number.parseFloat);
    var bsp_ubat_min = Math.min.apply(Math, bsp_ubat_arr);
    var bsp_ubat_max = Math.max.apply(Math, bsp_ubat_arr);
    bsp_ubat_arr = average(bsp_ubat_arr, average_num);
    data.titles.push(bsp_battery_power_title);
    var bsp_ibat_arr = tofloat_avg(data.titles[bsp_ibat]);
    var bsp_battery_power_arr = bsp_ubat_arr.map((v, i) => bsp_ibat_arr[i] * v / 1000.0); // [kW]
    data[bsp_battery_power_title] = bsp_battery_power_arr;
    // TODO: bsp_soc with right Y axis (percents)
    var bsp_soc_arr = tofloat_avg(data.titles[bsp_soc]);
    function add_shared_attrs(vd) {
        return vd.map(d => Object.assign({
                pointRadius: 0,
                borderWidth: 1,
                fill: false,
        }, d));
    };
    let lines = csvs[0].trailer.filter(x => x.length >= 2 && x[0].substr !== undefined && x[0].substr(0, 1) == 'P')
        .reduce((acc, cur, i) => {
            acc[cur[0]] = cur[1];
            return acc;
        }, {});

    let charts = [];

    // Graph 1:
    // (Y1) battery voltage from BSP
    //      U-Bat max from XT
    // constant line from parameters P1108, P1140, P1156, P1164
    // (Y2) BSP Bat SOC
    // (X) three days
    let line_datasets = ['P1108', 'P1140', 'P1156', 'P1164']
        .filter(name => lines[name] !== undefined)
        .map((name, i) => {
            let val = lines[name];
            return {
                label: name,
                data: labels.map(unused => val),
                borderColor: 'rgb(' + i * 63 + ', 0, 0)',
                yAxisID: 'left-y-axis',
            };
        });

    var datasets_voltage = add_shared_attrs([
        {
            label: data.titles[bsp_ubat],
            borderColor: '#ff0000',
            data: bsp_ubat_arr,
            yAxisID: 'left-y-axis',
        },
        {
            label: data.titles[xt_ubat],
            borderColor: '#ff8000',
            data: xt_ubat_arr,
            yAxisID: 'left-y-axis',
        },
        {
            label: data.titles[bsp_soc],
            borderColor: '#00ff00',
            data: bsp_soc_arr,
            yAxisID: 'right-y-axis',
        },
    ].concat(line_datasets));
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
    charts.push({
        title: "voltage",
        datasets: datasets_voltage,
        scales: scales_voltage,
        options: {
            legend: {
                labels: {
                    filter: (item, data) => {
                        return item.text.substr(0, 1) != 'P';
                    },
                },
            },
        },
    });

    // Graph 2: (Y) P-ACin sum, P-ACout sum, P-Solar sum; (X) Three days
    var datasets_power = add_shared_attrs([
        {
            label: xt_pin_title,
            borderColor: '#ff00ff',
            data: xt_pin_arr,
            yAxisID: 'left-y-axis',
        },
        {
            label: xt_pout_title,
            borderColor: '#ff00ff',
            data: xt_pout_arr,
            yAxisID: 'left-y-axis',
        },
        {
            label: bsp_battery_power_title,
            borderColor: '#ff00ff',
            data: bsp_battery_power_arr,
            yAxisID: 'left-y-axis',
        },
        {
            label: data.titles[solar_power_all],
            borderColor: '#0000ff',
            data: tofloat_avg(data.titles[solar_power_all]),
            yAxisID: 'left-y-axis',
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

    charts.push({
        title: "power",
        datasets: datasets_power,
        scales: scales_power,
    });

    // Graph 3: (Y) E-ACin sum, E-ACout sum, E-Solar sum; (X) Thirty days
    // TODO

    // Graph 4: (Y1) BSP I-Bat; (Y2) BSP Tbat; (X) Three days
    var datasets_i_tmp = add_shared_attrs([
        {
            label: data.titles[bsp_ibat],
            borderColor: '#0000ff',
            data: bsp_ibat_arr,
            yAxisID: 'left-y-axis',
        },
        {
            label: data.titles[bsp_tbat].replace(/./g, x => replace_high(x, '')),
            borderColor: '#00ffff',
            data: tofloat_avg(data.titles[bsp_tbat]),
            yAxisID: 'right-y-axis',
        },
    ]);
    var scales_i_tmp = {
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
    charts.push({
        title: "bat-I-temp",
        datasets: datasets_i_tmp,
        scales: scales_i_tmp,
    });

    return {
        charts: charts,
        labels: labels,
        time: time,
        date_start: date_start,
        date_end: date_end,
        csv_version: data.csv_version,
    };
}


export default extract_datasets;
