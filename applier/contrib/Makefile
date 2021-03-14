TARGETS := $(addsuffix /main.json, $(basename $(wildcard *.url)))

.PHONY: all
all: $(TARGETS)

%/main.json: %.url
	mkdir -p $(dir $@)
	curl -Lsfo "$<.tmp.in" "$(shell cat $<)"
	./manifests2json < "$<.tmp.in" > "$<.tmp"
	rm "$<.tmp.in"
	mv "$<.tmp" "$@"

.PHONY: clean
clean:
	rm -rf $(TARGETS) *.tmp *.tmp.in
