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

Vue.component("csv-row", {
    props: ["row"],
    template: `\
        <li>\
            <div v-for="cell in cells">\
            {{cell}}
            </div>\
        </li>\
    `,
    computed: {
        cells: function () {
            var ret = this.row.split(","); // correct only if no quotes
            console.log("in cells: " + this + ", this.row = " + this.row + " and returning " + JSON.stringify(ret));
            return ret;
        }
    }
});

window.App = new Vue({
  el: '#app',
  data: {
    message: 'Hello Vue.js!',
    seen: true,
    lines: [
        "1,2",
        "3,4",
    ]
  },
  computed: {
    csvrows: function() {
        ret = [];
        for (var index in this.lines) {
            ret.push({id: index, line: this.lines[index]});
        }
        console.log("csvrows: returning " + JSON.stringify(ret));
        return ret;
    }
  }
})
