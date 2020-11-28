# Default target executed when no arguments are given to make.
default: all

.PHONY: default help depend test publish integration-test

help:			## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

#==============================================================================

all: depend test integration-test

depend:			## Build dependencies
	pub get
	./install.sh

test: 			## Test all targets
	pub run build_runner build
	pub run test

.ONESHELL: # run all lines of the following target in a single shell instance
integration-test:	## Execute integration tests
	cd example/flutter/objectbox_demo/
	flutter pub get
	flutter pub run build_runner build
	flutter drive --verbose --target=test_driver/app.dart

publish: 		## Publish all packages to pub.dev
	echo "TODO implement publishing"
