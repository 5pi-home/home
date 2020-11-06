SOURCES := $(wildcard site/*.jsonnet)
NAMES   := $(SOURCES:site/%.jsonnet=%)
TARGETS := $(addprefix build/,$(addsuffix .json, $(NAMES:/=)))

.PHONY: all
all: $(TARGETS)

.PHONY: apply
apply: all
	kubectl apply -f build/*

build/%.json: site/%.jsonnet
	mkdir -p build/
	jsonnet $(shell ./bin/render-extvar $*) -J vendor -J lib $< -o $@

.PHONY: clean
clean:
	rm -rf build/*

echo:
	echo $(SOURCES)
	echo $(NAMES)
	echo $(TARGETS)


