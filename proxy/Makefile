COFFEE=$(shell find . \( -name node_modules -or -name bin \) -and -type d -prune -or -name '*.coffee' -print)
JS=$(patsubst %.coffee,%.js,$(COFFEE))

TWERP=`which twerp`

%.js: %.coffee
	coffee -b -c $<

all: $(JS)

publish: $(JS) bin
	npm publish

link: clean
	npm link ../base

bin: apiaxle-proxy.js
	sed -i '1i#!/usr/bin/env node' $<

test: clean
	$(TWERP) $(MY_TWERP_OPTIONS) `find test -name '*_test.coffee'`

coverage: $(JS) link
	istanbul cover $(TWERP) `find test -name '*_test.js'`

clean:
	@rm -fr $(JS) coverage

.PHONY: clean test coverage link
