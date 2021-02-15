SOURCES  := $(wildcard site/*.jsonnet)
NAMES    := $(SOURCES:site/%.jsonnet=%)
TARGETS  := $(addprefix build/,$(addsuffix .json, $(NAMES:/=)))
ROOT     := $(dir $(lastword $(MAKEFILE_LIST)))

.PHONY: all
all: $(TARGETS)

.PHONY: apply
apply: all
	kubectl apply -f build/*

build/%.json: site/%.jsonnet
	mkdir -p build/
	jsonnet $(shell $(ROOT)/bin/render-extvar $*) -J $(ROOT)/vendor -J $(ROOT)/lib $< -o $@


test/build/%.json: test/site/%.jsonnet
	mkdir -p test/build/
	jsonnet -J vendor -J lib $< -o $@

.PHONY: clean
clean:
	rm -rf build/*

.PHONY: update-fixtures
update-fixtures:
	make -C test -f ../Makefile

.PHONY: test
test:
	./bin/diff-build test
echo:
	echo $(SOURCES)
	echo $(NAMES)
	echo $(TARGETS)


