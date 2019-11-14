0.5.0 (2019-11-15)
------------------
* Dart 2.6 support - breaking change due to Dart 2.6 FFI changes.
  Please keep using 0.4 if you're on Dart 2.5 or Flutter. Currently no Flutter version comes with Dart 2.6 final.
  (thanks [Jasm Sison](https://github.com/Buggaboo) for [#54](https://github.com/objectbox/objectbox-dart/pull/57))

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
