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

window.App = new Vue({
  el: '#app',
  data: {
    chartData: [
    {
      labels: ['January', 'February', 'March', 'April', 'May', 'June', 'July'],
      datasets: [
        {
          label: 'Data One',
          backgroundColor: '#f87979',
          data: [40, 39, 10, 40, 39, 80, 40]
        },
        {
          label: 'Data Two',
          backgroundColor: '#88f939',
          data: [20, 29, 40, 50, 29, 50, 30]
        }
      ]
    },
    {
      labels: ['January', 'February', 'March', 'April', 'May', 'June', 'July'],
      datasets: [
        {
          label: 'Data Two',
          backgroundColor: '#88f939',
          data: [20, 29, 40, 50, 29, 50, 30]
        }
      ]
    }
    ],
    chartOptions: {
        responsive: true, maintainAspectRatio: false
    },
    first: true
  },
  computed: {
    chart_summary: function() {
        return "not done yet";
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
