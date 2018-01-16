# vim: filetype=javascript
<script>
import Vue from 'vue';
import { Bar } from 'vue-chartjs';

Vue.component("bar-chart", {
    extends: Bar,
    props: ['data', 'options'],
    mounted: function () {
        this.renderChart(this.data, this.options);
    }
});

export default {
  name: 'line_chart'
}

</script>
