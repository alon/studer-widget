'use strict'

console.log('node environment is: ' + process.env.NODE_ENV);

const path = require('path');
const TerserJsPlugin = require('terser-webpack-plugin');
const webpack = require('webpack');
const { VueLoaderPlugin } = require('vue-loader');

const vueLoaderConfig = {
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

let plugins_prod = [
    new VueLoaderPlugin(),
    new TerserJsPlugin({}),
    new webpack.DefinePlugin({
        'process.env': {
            NODE_ENV: '"production"',
        }
    }),
 ];
let plugins_dev = [
    new VueLoaderPlugin(),
];
let plugins = process.env.NODE_ENV == 'production' ? plugins_prod : plugins_dev;

module.exports = {
 entry: {
     app: './widget/widget.js',
 },
 plugins: plugins,
 resolve: {
   extensions: ['.js', '.vue', '.json'],
   // TODO: avoid this - should be able to ditch the compiler if I can only figure how to pass the csv computation to the app component.
   /*
   alias: {
     'vue$': 'vue/dist/vue.esm.js' // 'vue/dist/vue.common.js' for webpack 1
   }
   */
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
     {
       test: /\.css$/,
       use: [
         'vue-style-loader',
         'css-loader'
       ]
     },
     ]
 }
}
