window.CSV = (function() {
    return {
        read: function (fulltext) {
        /*
            lines = [];
            for c in 
*/
        }
    }
})();

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


function create_graph(response)
{
    window.Response = response; // for debugging
    var data = parse_csv(response.data);
    window.Data = data;
    var label_uin = 'XT-Uin [Vac]';
    var label_iin = 'XT-Iin [Aac]';
    var time = data.time.map(function (t) { return t.split(' ')[1]; });
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
        time: time,
        csv_version: data.csv_version,
        chartData:
        {
          labels: time,
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
            if (start.split(' ')[0] == last.split(' ')[0]) {
                last = last.split(' ')[1];
            }
            return "XT Log: " + start + ".." + last
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

// Not sure: show a "waiting" thing first?
// Right now:
//  start XHR for CSV
//   - meanwhile showing nothing
//  when it arrives, create chart
//   - which will contain all charts

axios.get('LG160704.CSV')
    .then(create_graph);


