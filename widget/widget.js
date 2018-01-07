import line_chart from './line_chart';
import Vue from 'vue';
import moment from 'moment';
import axios from 'axios';
import Chart from 'chart.js';
import VueChartJs from 'vue-chartjs';

"use strict";


function str__a_minus_b(a, b)
{
    for (var i = Math.min(a.length, b.length) - 1; i >= 0 ; --i)
    {
        if (a[i] != b[i])
        {
            return a.substring(0, i + 1);
        }
    }
    return '';
}


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


function create_graph(response)
{
    //G_Response = response; // for debugging
    var csvs = response.map(res => parse_csv(res.data));
    //G_CSVS = csvs;
    var data = merge_csv(csvs);
    var parts = data.time.map(x => x.split(' '));
    var date_start = parts[0][0];
    var date_end = parts[parts.length - 1][0];
    var time = parts.map(p => {
        var day_month_year = p[0].split('.');
        var hour_minute = p[1].split(':');
        return new Date(day_month_year[2] + '-' + day_month_year[1] + '-' + day_month_year[0]
            + 'T' + hour_minute[0] + ':' + hour_minute[1] + ':00.000');
    });
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
    var bsp_ubat_arr = data[data.titles[bsp_ubat]];
    var bsp_ubat_min = Math.min.apply(Math, bsp_ubat_arr);
    var bsp_ubat_max = Math.max.apply(Math, bsp_ubat_arr);
    data.titles.push(bsp_battery_power_label);
    var bsp_ibat_arr = data[data.titles[bsp_ibat]];
    data[bsp_battery_power_label] = data[data.titles[bsp_ubat]].map((v, i) => bsp_ibat_arr[i] * v / 1000.0); // units of kW
    // TODO: bsp_soc with right Y axis (percents)
    var datasets_voltage = [
        {
            label: data.titles[bsp_ubat],
            borderColor: '#ff0000',
            data: data[data.titles[bsp_ubat]],
            yAxisID: 'left-y-axis',
        },
        {
            label: data.titles[bsp_soc],
            borderColor: '#00ff00',
            data: data[data.titles[bsp_soc]],
            yAxisID: 'right-y-axis',
        },
    ];
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

    var datasets_power = [
        {
            label: data.titles[solar_power_all],
            borderColor: '#0000ff',
            data: data[data.titles[solar_power_all]],
            yAxisID: 'left-y-axis',
        },
        {
            label: data.titles[bsp_battery_power],
            borderColor: '#ff00ff',
            data: data[data.titles[bsp_battery_power]],
            yAxisID: 'left-y-axis',
        },
        {
            label: data.titles[bsp_tbat],
            borderColor: '#00ffff',
            data: data[data.titles[bsp_tbat]],
            yAxisID: 'right-y-axis',
        },
    ];
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

    window.Datasets = [datasets_voltage, datasets_power];
    window.App = new Vue({
      el: '#app',
      template: '<div>\n' +
                '  <p id="title">{{ chart_title }}</p>\n' +
                '    <line-chart id="chart-voltage"\n' +
                '      :data="chartDataVoltage"\n' +
                '      :options="chartOptionsVoltage"/>\n' +
                '    <line-chart id="chart-power"\n' +
                '      :data="chartDataPower"\n' +
                '      :options="chartOptionsPower"/>\n' +
                '</div>'
      ,
      data: {
        date_start: date_start,
        date_end: date_end,
        time: time,
        csv_version: data.csv_version,
        chartDataVoltage:
        {
            labels: labels,
          datasets: datasets_voltage,
        },
        chartOptionsVoltage: {
            responsive: true,
            maintainAspectRatio: false, /* default */
            /* TODO: figure out how to have a vertical cursor, i.e. always highlight points on the current time cursor is on (no need to be near on the y-axis) */
            tooltips: {
                intersect: false,
                mode: 'index',
            },
            scales: scales_voltage,
        },
        chartDataPower:
        {
            labels: labels,
            datasets: datasets_power,
        },
        chartOptionsPower: {
            responsive: true,
            maintainAspectRatio: false, /* default */
            /* TODO: figure out how to have a vertical cursor, i.e. always highlight points on the current time cursor is on (no need to be near on the y-axis) */
            tooltips: {
                intersect: false,
                mode: 'index',
            },
            scales: scales_power,
        },
      },
      computed: {
        chart_title: function() {
            var last = this.time[this.time.length - 1];
            var start = this.time[0];

            return "XT Log: " + str__a_minus_b(this.date_start, this.date_end) + ' ' + ".." + ' ' + this.date_end 
                + " (" + this.csv_version + ")";
        },
        second: function() {
            console.log("second called");
            return !this.first;
        }
      },
      methods: {
          checked: function() {
              this.first = !this.first;
          }
      },
    });
}


function getParamValue(paramName)
{
    var url = window.location.search.substring(1); //get rid of "?" in querystring
    var qArray = url.split('&'); //get key-value pairs
    for (var i = 0; i < qArray.length; i++) 
    {
        var pArr = qArray[i].split('='); //split key and value
        if (pArr[0] == paramName) {
            return pArr[1]; //return value
        }
    }
}

function get_all_csv_files(response)
{
    var data = (response.data);
    // TODO: return all. sstart with one
    var promises = [];
    var lines = data.split('\n');
    for (var i = 0 ; i < lines.length ; ++i)
    {
        promises.push(axios.get(lines[i]));
    }
    return Promise.all(promises); // TODO: what are the requirements? should I have alternative implementations?
}


var csv_url = getParamValue("csv");

// Not sure: show a "waiting" thing first?
// Right now:
//  start XHR for CSV
//   - meanwhile showing nothing
//  when it arrives, create chart
//   - which will contain all charts

function extension(name)
{
    var dot = name.search('[.]');
    return name.substring(dot + 1);
}

if (extension(csv_url).toLocaleLowerCase() == "csv") {
    axios.get(csv_url)
        .then(create_graph);
} else {
    axios.get(csv_url)
        .then(get_all_csv_files)
        .then(create_graph);
}

