# Generator integration tests

Run using the [`../test.sh`](../test.sh) script:
```
# Run all tests
../test.sh

# Run a specific test
../test.sh <directory>
```

Each subdirectory contains a test case, a complete dart package (with some shared files: pubspec.yaml, test_env.dart, ...).
* before a test starts, it's content is cleaned by running `git clean -fXd directory-path`, i.e. removing all ignored files 
* each directory may contain `[0-9].dart` test files which are executed in ascending order using `pub run test N.dart` 
* `pub run build_runner build` is executed before each test file, except `0.dart`
* you can skip any number (including `0.dart`) - if the file is not there, the test.sh will just skip it
* tests are allowed to make changes to the file system in their directory and these are preserved between test files, 
    but not removed between test-case runs
* additionally, there may be `[0-9]-pre.dart` command-line apps, which are executed `dart N-pre.dart` - these may be 
used to further prepare the environment **before** code generation for the step `N` is issued and `N.dart` test is run

## Development

To enable Dart Analysis, including code auto-complete, temporarily remove the `exclude` for this directory in
the parent [analysis_options.yaml](../analysis_options.yaml).
  
## Troubleshooting

```
Invalid argument(s): Failed to load dynamic library 'lib/objectbox.dll'
```
Ensure `objectbox-c` is installed globally, or in the tested directory run [`../../../install.sh`](../../install.sh).