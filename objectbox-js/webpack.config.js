const path = require('path');

module.exports = {
  mode: "production",
  entry: './src/index.ts',
  devtool: 'source-map',
  module: {
    rules: [
      {
        test: /\.tsx?$/,
        use: 'ts-loader',
        exclude: /node_modules/,
      },
    ],
  },
  resolve: {
    extensions: ['.tsx', '.ts', '.js'],
  },
  output: {
    filename: 'objectbox.js',
    path: path.resolve(__dirname, 'build'),
    library: 'objectbox',
    libraryTarget: 'window'
  },
};
