# vim: filetype=javascript
<script>
import Vue from 'vue';
import VueChartJs from 'vue-chartjs';
import Chart from 'chart.js'; // not sure this is required

Vue.component("line-chart", {
    extends: VueChartJs.Line,
    props: ['data', 'options'],
    mixins: [VueChartJs.mixins.reactiveProp, VueChartJs.mixins.reactiveData],
    mounted() {
        this.renderChart(this.data, this.options);
    }
});

export default {
  name: 'line_chart'
}

</script>
