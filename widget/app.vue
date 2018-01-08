# vim: filetype=javascript
<template>
<div>
  <p id="title">{{ chart_title }}</p>
    <line-chart id="chart-voltage"
      :data="chartDataVoltage"
      :options="chartOptionsVoltage"/>
    <line-chart id="chart-power"
      :data="chartDataPower"
      :options="chartOptionsPower"/>
</div>
</template>
<script>
import line_chart from './line_chart'; // TODO is this required - the dependency is via the template, not script
import { str__a_minus_b } from './util';

export default {
  props: [
    'average_num',
    'csv_version',
    'time',
    'date_start',
    'date_end',
    'chartDataVoltage',
    'chartDataPower',
    'chartOptionsVoltage',
    'chartOptionsPower'
  ],
  computed: {
    chart_title: function() {
        var last = this.time[this.time.length - 1];
        var start = this.time[0];

        return "XT Log: " + str__a_minus_b(this.date_start, this.date_end) + ' ' + ".." + ' ' + this.date_end 
            + " (" + this.csv_version + ")" + ' Avg ' + this.average_num;
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
};
</script>
<style>
</style>
