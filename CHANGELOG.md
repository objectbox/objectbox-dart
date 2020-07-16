0.6.4 (2020-05-12)
------------------
* Update to objectbox-swift 1.3.0
* Update to objectbox-android 2.5.1

0.6.3 (2020-05-07)
------------------
* Update FlatBuffers to 1.12.0
* Provide error hinting when DB can't be created (e.g. when an app docs directory isn't passed properly on Flutter).

0.6.2 (2020-03-09)
------------------
* Support large object arrays on 32-bit platforms/emulators.

0.6.1 (2020-01-23)
------------------
* Fix Flutter Android/iOS release build failures
* Updated to objectbox-c 0.8.2

0.6.0 (2019-12-19)
------------------
* Flutter iOS support
* Generator fixes and rework to support multiple entity files in addition to many entities in a single file. 
    Please move `objectbox-model.json` to `lib/` before running the generator. 
* Simplified Android support (automatic dependency).
* Docs improvements
* Updated to objectbox-c 0.8.1

0.5.0 (2019-11-18)
------------------
* Dart 2.6 support - breaking change due to Dart 2.6 FFI changes.
  Please keep using 0.4 if you're on Dart 2.5/Flutter 1.9. 
  (thanks [Jasm Sison](https://github.com/Buggaboo) for [#57](https://github.com/objectbox/objectbox-dart/pull/57))
* Docs fixes & improvements

0.4.0 (2019-10-31)
------------------
* Flutter Android support
* Queries for all currently supported types  
    (thanks [Jasm Sison](https://github.com/Buggaboo) for [#27](https://github.com/objectbox/objectbox-dart/pull/27) and [#46](https://github.com/objectbox/objectbox-dart/pull/46))
* More Box functions (count, isEmpty, contains, remove and their bulk variants)
    (thanks [liquidiert](https://github.com/liquidiert) for [#42](https://github.com/objectbox/objectbox-dart/pull/42) and [#45](https://github.com/objectbox/objectbox-dart/pull/45))
* Explicit write transactions
    (thanks [liquidiert](https://github.com/liquidiert) for [#50](https://github.com/objectbox/objectbox-dart/pull/50))
* Resolved linter issues
    (thanks [Gregory Sech](https://github.com/GregorySech) for [#31](https://github.com/objectbox/objectbox-dart/pull/31))
* Updated to objectbox-c 0.7.2
* First release on pub.dev

0.3.0 (2019-10-15)
------------------
* ID/UID generation and model persistence (objectbox-model.json)
* CI tests using GitHub Actions
* Code cleanup, refactoring and formatting 
    (thanks [Jasm Sison](https://github.com/Buggaboo) for [#20](https://github.com/objectbox/objectbox-dart/pull/20) & [#21](https://github.com/objectbox/objectbox-dart/pull/21))

0.2.0 (2019-09-11)
------------------
* UTF-8 support for Store and Box 
    (thanks [Jasm Sison](https://github.com/Buggaboo) for [#14](https://github.com/objectbox/objectbox-dart/pull/14)!)
* Bulk put and get functions (getMany, getAll, putMany)
* Updated to objectbox-c 0.7
* Basic Store options
* Minimal unit tests
* Removed reflection code, switched to model code generation instead
* Minimal Flutter Desktop example for Dart 2.5.0

0.1.0 (2019-09-03)
------------------
* Minimal Store setup
* Minimal Box with put and get
