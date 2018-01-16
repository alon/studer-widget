# vim: filetype=javascript
<template>
<div>
  <p id="title">{{ chart_title }}</p>
    <div v-for="chart in charts">
    <bar-chart v-if="chart.type == 'bar'"
      :key="chart.key"
      :data="chart.data"
      :options="chart.options"/>
    <line-chart v-if="chart.type == 'line'"
      :key="chart.key"
      :data="chart.data"
      :options="chart.options"/>
    </div>
    <select v-model="extra">
		<option disabled value="">Extra</option>
		<option value="constants">constants</option>
		<option value="download">download</option>
	</select>
    <div v-show="extra == 'constants'">
      <table>
      <tr v-for="constant in Object.keys(constants)">
          <td>{{ constant }}</td><td>{{ constants[constant] }}</td>
      </tr>
      </table>
    </div>
    <div v-show="extra == 'download'">
      <div v-for="filename in filenames">
        <a :href="filename">{{filename}}</a>
      </div>
    </div>
</div>
</template>
<script>
import line_chart from './line_chart'; // TODO is this required - the dependency is via the template, not script
import bar_chart from './bar_chart'; // TODO is this required - the dependency is via the template, not script
import { str__a_minus_b } from './util';

export default {
  props: [
    'average_num',
    'csv_version',
    'time',
    'date_start',
    'date_end',
    'charts',
    'constants',
    'filenames',
  ],
  data: () => {
    return { extra: '' };
  },
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
