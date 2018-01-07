<script>
import Vue from 'vue';

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
