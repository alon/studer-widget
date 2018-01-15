let readFileSync = require('fs').readFileSync;
let process = require('./process.js').default;
let data = readFileSync('LG171218.CSV', 'utf8');
process([{data: data}], 1);
