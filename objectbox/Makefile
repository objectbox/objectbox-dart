# Default target executed when no arguments are given to make.
default: help

.PHONY: default help depend integration-test

help:			## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

#==============================================================================

depend:			## Build dependencies
	../install.sh
	dart pub get

integration-test:	## Execute integration tests
	./tool/integration-test.sh example/flutter/objectbox_demo
	./tool/integration-test.sh example/flutter/objectbox_demo_relations
	./tool/integration-test.sh example/flutter/objectbox_demo_sync
