COFFEE=$(shell find . \( -name node_modules -or -name bin \) -and -type d -prune -or -name '*.coffee' -print)
JS=$(patsubst %.coffee,%.js,$(COFFEE))
TGZ=$(shell find . -name '*.tgz' -print)

TWERP=`which twerp`

%.js: %.coffee
	coffee -b -c $<

all: $(JS)

README.md: ../README.md
	cp ../$@ .

publish: clean README.md $(JS) bin
	npm publish

package: clean README.md $(JS) bin
	npm pack

run:
	coffee -w "lib,app" ./apiaxle-api.coffee

npminstall:
	npm install

link:
	npm link ../base

bin: apiaxle-api.js
	sed -i '1i#!/usr/bin/env node' $<

test:
	$(TWERP) $(MY_TWERP_OPTIONS) `find test -name '*_test.coffee'`

coverage: link $(JS)
	istanbul cover $(TWERP) `find test -name '*_test.js'`

clean:
	@rm -vfr $(JS) coverage $(TGZ)

.PHONY: clean test coverage link publish package
