'use strict'
const path = require('path');
var webpack = require('webpack');
var vueLoaderConfig = {
  //loaders: utils.cssLoaders({
  //  sourceMap: sourceMapEnabled,
  //  extract: isProduction
  //}),
  //cssSourceMap: sourceMapEnabled,
  //cacheBusting: config.dev.cacheBusting,
  transformToRequire: {
    video: ['src', 'poster'],
    source: 'src',
    img: 'src',
    image: 'xlink:href'
  }
};

module.exports = {
 entry: {
     app: './widget/widget.js',
 },
 plugins: [
 /*
    new webpack.DefinePlugin({
        'process.env': {
            NODE_ENV: '"production"',
        }
    }),
    */
 ],
 resolve: {
   extensions: ['.js', '.vue', '.json'],
 },
 output: {
     path: path.resolve(__dirname, 'widget'),
     filename: 'widget.bundle.js',
 },
 module: {
     rules: [
     {
        test: /\.vue$/,
        loader: 'vue-loader',
        options: vueLoaderConfig
     },
     /*
     {
         test: /\.html$/,
         use: 'vue-template-loader'
     }
     */
     {
         test: /\.js?$/,
         exclude: /node_modules/,
         use: {
             loader: 'babel-loader?cacheDirectory=true',
         }
     },
     ]
 }
}
