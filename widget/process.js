// vim: tabstop=4 expandtab shiftwidth=4
'use strict';

import { build_object } from './util';


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


function merge_csv(sorted)
{
    // Note: ignores csv_version, extra_header, trailer
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

function first_prefix_match_offset(l, prefix) {
    for (var i = 0 ; i < l.length ; ++i)
    {
        if (l[i].substr(0, prefix.length) == prefix) {
            return i;
        }
    }
    console.error('could not find ' + prefix + ' in titles: ' + l);
    return 0;
}


function parse_time(time)
{
    var parts = time.map(x => x.split(' '));
    var date_start = parts[0][0];
    var date_end = parts[parts.length - 1][0];
    var time_full = parts.map((p, i) => {
        var day_month_year = p[0].split('.');
        var hour_minute = p[1].split(':');
        return new Date(day_month_year[2] + '-' + day_month_year[1] + '-' + day_month_year[0]
            + 'T' + hour_minute[0] + ':' + hour_minute[1] + ':00.000');
    });
    return {time_full: time_full, date_start: date_start, date_end: date_end};
}


function parse_studer_csvs(csvs, average_num)
{
    let short_to_title_prefix = {
        xt_ubat: 'XT-Ubat',
        xt_ibat: 'XT-Ibat',
        xt_pin: 'XT-Pin',
        xt_pout: 'XT-Pout',
        bsp_ubat: 'BSP-Ubat',
        bsp_ibat: 'BSP-Ibat',
        bsp_soc: 'BSP-SOC',
        bsp_tbat: 'BSP-Tbat',
        solar_power_all: 'Solar power (ALL)',
    };

    var sorted = csvs.map((c, i) => [csv_date(c.time[0]), i]).sort((a, b) => a[0] < b[0] ? -1 : (a[0] == b[0] ? 0 : 1)).map(x => csvs[x[1]]);
    var recent_csv = merge_csv(sorted.slice(sorted.length - 3, sorted.length));
    var d_short_to_title_num = build_object(Object.keys(short_to_title_prefix), k => first_prefix_match_offset(recent_csv.titles, short_to_title_prefix[k]));
    var recent = build_object(Object.keys(d_short_to_title_num), k => recent_csv[recent_csv.titles[d_short_to_title_num[k]]].map(Number.parseFloat));
    recent.bsp_battery_power = recent.bsp_ubat.map((v, i) => recent.bsp_ibat[i] * v / 1000.0); // [kW]

    var bsp_battery_power_title = 'BSP Battery Power [kW]';

    let constants = csvs[0].trailer.filter(x => x.length >= 2 && x[0].substr !== undefined && x[0].substr(0, 1) == 'P')
        .reduce((acc, cur, i) => {
            acc[cur[0]] = cur[1];
            return acc;
        }, {});

    var time_data = parse_time(recent_csv.time);
    var time_full = time_data.time_full;
    var time = decimate_first_of(time_full, average_num);

    var titles = short_to_title_prefix;
    titles.bsp_battery_power = bsp_battery_power_title;

    let averaged = build_object(Object.keys(recent), k => average(recent[k], average_num));

    let energy_time = sorted.map(x => {
        let d = csv_date(x.time[0]);
        return new Date(d.getUTCFullYear(), d.getMonth(), d.getDate(), 0, 0, 0)
    });

    let daily = build_object(['solar_power_all', 'xt_pin', 'xt_pout'], shrt => {
        let title = recent_csv.titles[d_short_to_title_num[shrt]];
        return sorted.map(csv =>
            csv[title]
            .map(Number.parseFloat)
            .reduce((acc, cur, i) => acc + cur, 0));
    });

    daily.time = energy_time;

    return {
        recent: {
            bsp_ubat_min: Math.min.apply(Math, recent.bsp_ubat),
            bsp_ubat_max: Math.max.apply(Math, recent.bsp_ubat),
            time: time,
            cols: averaged,
        },
        daily: daily,
        titles: titles,
        constants: constants,
        date_start: time_data.date_start,
        date_end: time_data.date_end,
        csvs: csvs,
    };
}


function add_shared_attrs(vd) {
    return vd.map(d => Object.assign({
            pointRadius: 0,
            borderWidth: 1,
            fill: false,
    }, d));
};


let gridLines05 = {
    display: true,
    color: 'rgba(0, 0, 0, 0.5)',
};

function make_recent_charts(d, labels)
{
    var recent = d.recent;
    var constants = d.constants;
    var cols = recent.cols;
    var titles = d.titles;
    var charts = [];

    let timeXAxes = [{
        type: 'time',
        // TODO: show Day Hour Hour Hour Day .. ; currently just Hour Hour Hour
        time: {
            unit: 'hour',
            stepSize: 2,
        },
        gridLines: gridLines05,
    }];

    // Graph 1:
    // (Y1) battery voltage from BSP
    //      U-Bat max from XT
    // constant line from parameters P1108, P1140, P1156, P1164
    // (Y2) BSP Bat SOC
    // (X) three days
    let voltage_constants = build_object(['P1108', 'P1140', 'P1156', 'P1164'], c => Number.parseFloat(constants[c]));
    let voltage_constants_values = Object.values(voltage_constants);
    let line_datasets =
        Object.keys(voltage_constants)
        .filter(name => constants[name] !== undefined)
        .map((name, i) => {
            let val = constants[name];
            return {
                label: name,
                data: labels.map(unused => val),
                borderColor: 'rgb(' + i * 63 + ', 0, 0)',
                yAxisID: 'left-y-axis',
            };
        });

    var datasets_voltage = add_shared_attrs([
        {
            label: titles.bsp_ubat,
            borderColor: '#ff0000',
            data: cols.bsp_ubat,
            yAxisID: 'left-y-axis',
        },
        {
            label: titles.xt_ubat,
            borderColor: '#ff8000',
            data: cols.xt_ubat,
            yAxisID: 'left-y-axis',
        },
        {
            label: titles.bsp_soc,
            borderColor: '#00ff00',
            data: cols.bsp_soc,
            yAxisID: 'right-y-axis',
        },
    ].concat(line_datasets));
    var scales_voltage = {
        yAxes: [{
            id: 'left-y-axis',
            type: 'linear',
            position: 'left',
            ticks: {
                min: Math.min(recent.bsp_ubat_min, Math.min.apply(Math, voltage_constants_values)) - 0.1,
                max: Math.max(recent.bsp_ubat_max, Math.max.apply(Math, voltage_constants_values)) + 0.1,
            },
            scaleLabel: {
                display: true,
                labelString: 'Voltage [V]',
            },
        }, {
            id: 'right-y-axis',
            type: 'linear',
            position: 'right',
            scaleLabel: {
                display: true,
                labelString: 'State of charge [%]',
            },
        }],
        xAxes: timeXAxes,
    };
    charts.push({
        title: "voltage",
        datasets: datasets_voltage,
        scales: scales_voltage,
        labels: labels,
        type: 'line',
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
            label: titles.xt_pin,
            borderColor: '#ffff00',
            data: cols.xt_pin,
            yAxisID: 'y-axis',
        },
        {
            label: titles.xt_pout,
            borderColor: '#ff00ff',
            data: cols.xt_pout,
            yAxisID: 'y-axis',
        },
        {
            label: titles.bsp_battery_power,
            borderColor: '#00ffff',
            data: cols.bsp_battery_power,
            yAxisID: 'y-axis',
        },
        {
            label: titles.solar_power_all,
            borderColor: '#0000ff',
            data: cols.solar_power_all,
            yAxisID: 'y-axis',
        },
    ]);
    var scales_power = {
        yAxes: [{
            id: 'y-axis',
            type: 'linear',
            position: 'left',
            scaleLabel: {
                display: true,
                labelString: 'Power [kW]',
            },
            gridLines: gridLines05,
        }],
        xAxes: timeXAxes,
    };

    charts.push({
        title: "power",
        datasets: datasets_power,
        scales: scales_power,
        labels: labels,
        type: 'line',
    });

    // Graph 4: (Y1) BSP I-Bat; (Y2) BSP Tbat; (X) Three days
    var datasets_i_tmp = add_shared_attrs([
        {
            label: titles.bsp_ibat,
            borderColor: '#0000ff',
            data: cols.bsp_ibat,
            yAxisID: 'left-y-axis',
        },
        {
            label: titles.bsp_tbat.replace(/./g, x => replace_high(x, '')),
            borderColor: '#00ffff',
            data: cols.bsp_tbat,
            yAxisID: 'right-y-axis',
        },
    ]);
    var scales_i_tmp = {
        yAxes: [{
            id: 'left-y-axis',
            type: 'linear',
            position: 'left',
            scaleLabel: {
                display: true,
                labelString: 'Current [A]',
            },
            gridLines: gridLines05,
        }, {
            id: 'right-y-axis',
            type: 'linear',
            position: 'right',
            scaleLabel: {
                display: true,
                labelString: 'Temperature [C]',
            },
        }],
        xAxes: timeXAxes,
    };
    charts.push({
        title: "bat-I-temp",
        datasets: datasets_i_tmp,
        scales: scales_i_tmp,
        labels: labels,
        type: 'line',
    });

    return charts;
}


function extract_datasets(response, average_num)
{
    var csvs = response.map(res => parse_csv(res.data));
    var d = parse_studer_csvs(csvs, average_num);
    var time = d.recent.time;
    var labels = time;
    let charts = make_recent_charts(d, labels);

    // Graph 3: (Y) E-ACin sum, E-ACout sum, E-Solar sum; (X) Thirty days
    var datasets_avg = add_shared_attrs([
        {
            label: 'E-in',
            borderColor: '#ff0000',
            data: d.daily.xt_pin,
            yAxisID: 'left-y-axis',
        },
        {
            label: 'E-out',
            borderColor: '#0000ff',
            data: d.daily.xt_pout,
            yAxisID: 'left-y-axis',
        },
        {
            label: 'Solar',
            borderColor: '#00ff00',
            data: d.daily.solar_power_all,
            yAxisID: 'left-y-axis',
        },
    ]);
    var scales_avg = {
        yAxes: [{
            id: 'left-y-axis',
            type: 'linear',
            position: 'left',
            scaleLabel: {
                display: true,
                labelString: 'Energy [kWh]',
            },
            gridLines: gridLines05,
        }],
        xAxes: [{
            type: 'time',
            time: {
                unit: 'day',
            },
            gridLines: gridLines05,
        }],
    };
    charts.push({
        title: "daily averages",
        datasets: datasets_avg,
        scales: scales_avg,
        labels: d.daily.time,
        type: 'bar',
    });

    return {
        charts: charts,
        time: time,
        date_start: d.date_start,
        date_end: d.date_end,
        csv_version: d.csvs[0].csv_version,
        constants: d.constants,
    };
}


export default extract_datasets;
