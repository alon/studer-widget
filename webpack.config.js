var path = require('path');

module.exports = {
 entry: './widget/widget.js',
 output: {
     path: path.resolve(__dirname, 'dist'),
     filename: 'widget.bundle.js',
 },
}
