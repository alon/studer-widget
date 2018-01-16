let fs = require('fs');
let readFileSync = fs.readFileSync;
let filenames = fs.readdirSync('.').filter(x => x.substr(x.length - 3, x.length) == 'CSV' && x.substr(0, 4) != 'LG16');
console.log(filenames);
let extract_datasets = require('./process.js').default;
let data = filenames.map(fn => { return {data: readFileSync(fn, 'utf8')}; });
extract_datasets(data, 10);
