SOURCES := $(wildcard pkg/*)
NAMES   := $(SOURCES:pkg/%=%)
TARGETS := $(addprefix build/,$(addsuffix .json, $(NAMES:/=)))

.PHONY: all
all: $(TARGETS)

.PHONY: apply
apply: all
	kubectl apply -f build/*

build/%.json: pkg/%/main.libsonnet
	mkdir -p build/
	jsonnet -J vendor -J lib $< -o $@

.PHONY: clean
clean:
	rm -rf build/*
