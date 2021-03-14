SITE    ?= 5pi-home.jsonnet
JSONNET ?="java -jar ../sjsonnet.jar"

.PHONY: all
all: generate

.PHONY: generate
generate: jb_install contrib_install
	rm -rf "build/$(SITE)"
	./generate $(SITE)

.PHONY: jb_install
jb_install:
	jb install

.PHONY: contrib_install
contrib_install:
	make -C contrib

.PHONY: test
test:
	rm -rf "build/$(SITE).test-args/"
	./generate $(SITE) $(SITE).test-args
	git diff --exit-code build/$(SITE).test-args/
