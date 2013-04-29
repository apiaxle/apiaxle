COFFEE=$(shell find . \( -name node_modules -or -name bin \) -and -type d -prune -or -name '*.coffee' -print)
JS=$(patsubst %.coffee,%.js,$(COFFEE))

TWERP=`which twerp`

%.js: %.coffee
	coffee -b -c $<

all: $(JS)

README.md: ../README.md
	cp ../$@ .

publish: README.md $(JS) bin
	npm publish

npminstall: link
	npm install >/dev/null 2>&1

link: bin
	npm link ../base

bin: apiaxle-api.js
	sed -i '1i#!/usr/bin/env node' $<

test: clean npminstall
	$(TWERP) $(MY_TWERP_OPTIONS) `find test -name '*_test.coffee'`

coverage: link $(JS)
	istanbul cover $(TWERP) `find test -name '*_test.js'`

clean:
	@rm -fr $(JS) coverage

.PHONY: clean test coverage link
