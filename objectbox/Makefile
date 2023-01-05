# Default target executed when no arguments are given to make.
default: all

.PHONY: default help depend test coverage valgrind-test publish integration-test format

help:			## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

#==============================================================================

all: depend test valgrind-test integration-test

depend:			## Build dependencies
	dart pub get
	../install.sh

test: 			## Test all targets
	dart run build_runner build
	dart run test

coverage: 			## Calculate test coverage
	dart run build_runner build
    # Note: only flutter test generates `.lcov` - can't use `dart test`
	flutter test --coverage
	lcov --remove coverage/lcov.info 'lib/src/native/admin.dart' 'lib/src/native/sync.dart' 'lib/src/native/bindings/objectbox_c.dart' 'lib/src/native/bindings/bindings.dart' 'lib/src/modelinfo/*' -o coverage/lcov.info
	genhtml coverage/lcov.info -o coverage/html || true

valgrind-test: 		## Test all targets with valgrind
	dart run build_runner build
	./tool/valgrind.sh

integration-test:	## Execute integration tests
	./tool/integration-test.sh example/flutter/objectbox_demo
	./tool/integration-test.sh example/flutter/objectbox_demo_relations
	./tool/integration-test.sh example/flutter/objectbox_demo_sync

format:			## Format all code
	dart format .
