COFFEE=$(shell find . \( -name node_modules -or -name bin \) -and -type d -prune -or -name '*.coffee' -print)
JS=$(patsubst %.coffee,%.js,$(COFFEE))

TWERP=`which twerp`

%.js: %.coffee
	coffee -b -c $<

all: $(JS)

README.md: ../README.md
	cp ../$@ .

publish: clean README.md $(JS) bin
	npm publish

npminstall:
	npm install

link:
	$(MAKE) -C ../api bin
	npm link ../api
	npm link ../base

bin: apiaxle.js
	sed -i '1i#!/usr/bin/env node' $<

test:
	timeout 5 $(TWERP) $(MY_TWERP_OPTIONS) `find test -name '*_test.coffee'`

coverage: link $(JS)
	istanbul cover $(TWERP) `find test -name '*_test.js'`

clean:
	@rm -fr $(JS) coverage

.PHONY: clean test coverage link
