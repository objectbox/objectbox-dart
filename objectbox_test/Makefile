# Default target executed when no arguments are given to make.
default: help

.PHONY: default help depend test

help:			## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

#==============================================================================

depend:			## Build dependencies
	../install.sh
	dart pub get

test: 			## Generate code and run unit tests
	dart run build_runner build
	dart run test
