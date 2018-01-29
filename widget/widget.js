import axios from 'axios';
import Vue from 'vue';
import moment from 'moment'; // required by vue - needs to be loaded before use, used dynamically
import App from './app';
import extract_datasets from './process';
import build_object from './util';
import { } from 'iframe-resizer';

"use strict";

function create_graph(filenames, response, average_num)
{
    let d = extract_datasets(response, average_num);
    let csv_version = d.csv_version;
    let time = d.time;
    let date_start = d.date_start;
    let date_end = d.date_end;
    filenames.sort();

    window.App = new Vue({
      el: '#app',
      render: function(createElement) {
          return createElement(
            'app' /* tag name */,
            {props: {
                average_num: average_num,
                date_start: date_start,
                date_end: date_end,
                time: time,
                csv_version: csv_version,
                constants: d.constants,
                filenames: filenames,
                charts: d.charts.map(function (datum) {
                    return {
                        key: datum.title,
                        type: datum.type,
                        data: {
                            labels: datum.labels,
                            datasets: datum.datasets,
                        },
                        options: Object.assign(datum.options || {}, {
                            responsive: true,
                            maintainAspectRatio: false, /* default */
                            /* TODO: figure out how to have a vertical cursor, i.e. always highlight points on the current time cursor is on (no need to be near on the y-axis) */
                            tooltips: {
                                intersect: false,
                                mode: 'index',
                            },
                            scales: datum.scales,
                            elements: {
                                line: {
                                    tension: 0, // disables bezier curves
                                },
                            },
                            animation: {
                                duration: 0,
                            },
                            hover: {
                                animationDuration: 0,
                            },
                            responsiveAnimationDuration: 0,
                        }),
                    }; }),
            }},
            [] /* array of children */);
      },
      //template: '<App csv_version="csv_version"/>',
      components: { App },
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

function get_all_csv_files(root, response)
{
    var data = (response.data);
    var promises = [];
    var lines = data.split('\n');
    for (var i = 0 ; i < lines.length ; ++i)
    {
        if (/\.CSV$/.test(lines[i])) {
            let fullname = root === null || root.length === undefined || root.length === 0 ? lines[i] : root + '/' + lines[i];
            filenames.push(lines[i]);
            promises.push(axios.get(fullname));
        }
    }
    return Promise.all(promises); // TODO: what are the requirements? should I have alternative implementations?
}


let csv_url = getParamValue("csv");
let filenames = [];
let average_num = Number.parseFloat(getParamValue("average")) || 10;

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

function get_root_path(url)
{
    let scheme_index = url.indexOf('://');
    let path;
    if (scheme_index == -1) {
        path = url;
    } else {
        let after_scheme = url.split('://')[1];
        path = after_scheme.substr(after_scheme.indexOf('/') + 1, after_scheme.length);
    }
    let ind = path.lastIndexOf('/');
    return path.substring(0, ind);
}

let root = get_root_path(csv_url);

if (extension(csv_url).toLocaleLowerCase() == "csv") {
    axios.get(csv_url)
        .then(data => create_graph([csv_url], data, average_num));
} else {
    axios.get(csv_url)
        .then(response => get_all_csv_files(root, response))
        .then(data => create_graph(filenames, data, average_num));
}

