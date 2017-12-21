Vue.component("line-chart", {
    extends: VueChartJs.Line,
    mixins: [VueChartJs.mixins.reactiveProp, VueChartJs.mixins.reactiveData],
    mounted() {
        this.renderChart(this.chartData, this.chartOptions);
    }
});


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
    G_Response = response; // for debugging
    var csvs = response.map(res => parse_csv(res.data));
    G_CSVS = csvs;
    var data = merge_csv(csvs);
    var parts = data.time.map(x => x.split(' '));
    var date_start = parts[0][0];
    var date_end = parts[parts.length - 1][0];
    var time = parts.map(p => p[1]);
    var labels = parts.map(p => p[0].split('.')[0] + ' ' + p[1]);
    var colors = ['#f87979', '#88f939'];
    var datasets = [];
    var interesting_indices = [1, 4, 5];
    for (var i = 0 ; i < interesting_indices.length ; ++i) {
        var title = data.titles[interesting_indices[i]];
        datasets.push({
            label: title,
            color: colors[i % colors.length],
            data: data[title]
        });
    }
    window.Datasets = datasets;
    window.App = new Vue({
      el: '#app',
      template: '<div>\n' +
                '  <p id="title">{{ chart_title }}</p>\n' +
                '    <line-chart\n' +
                '      :chart-data="chartData"\n' +
                '      :chart-options="chartOptions"/>\n' +
                '</div>'
      ,
      data: {
        date_start: date_start,
        date_end: date_end,
        time: time,
        csv_version: data.csv_version,
        chartData:
        {
          labels: labels,
          datasets: datasets,
        },
        chartOptions: {
            responsive: true,
            maintainAspectRatio: true, /* default */
            /* TODO: figure out how to have a vertical cursor, i.e. always highlight points on the current time cursor is on (no need to be near on the y-axis) */
            tooltips: {
                intersect: false,
                mode: 'index',
            },
        },
      },
      computed: {
        chart_title: function() {
            var start = this.time[0];
            var last = this.time[this.time.length - 1];
            return "XT Log: " + this.date_start + ' ' + start + ".." + ' ' + this.date_end + ' ' + last
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

