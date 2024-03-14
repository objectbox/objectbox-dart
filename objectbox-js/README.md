# ObjectBox TS/JS (based on IndexedDB)

This is a very basic ObjectBox implementation for JavaScript/TypeScript, based on IndexedDB instead of the native objectbox-c API.

### Build and copy to objectbox-dart

The following code builds TypeScript files into `build` folder, uses `webpack` to create a single JS,
copies the JS (and sourcemap) to `../objectbox/lib/`, and generates dart binding code in `../objectbox/lib/src/web/`.
```shell
npm run build:main
npm run install
npm run generate:dart
```

Or run a single action to do it all:
```shell
npm run all:dart
```

### Notes and useful links about the compilation/integration:

* modules are not supported, we need to compile to a single JS file (using `webpack`)
* example: https://github.com/google/chartjs.dart/
* example: https://github.com/matanlurey/dart_js_interop
* modules issue: https://github.com/dart-lang/sdk/issues/25059
  
### IndexedDB resources

* https://developers.google.com/web/ilt/pwa/working-with-indexeddb
* https://www.tutorialspoint.com/html5/html5_indexeddb.htm
* https://javascript.info/indexeddb
