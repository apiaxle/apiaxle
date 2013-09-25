COFFEE=$(shell find . -name node_modules -and -type d -prune -or -name '*.coffee' -print)
JS=$(patsubst %.coffee,%.js,$(COFFEE))

TWERP=`which twerp`

%.js: %.coffee
	coffee -b -c $<

all: $(JS)

README.md: ../README.md
	cp ../$@ .

publish: clean README.md $(JS)
	npm publish

npminstall:
	npm install

link:

dev: clean

test:
	timeout 40 $(TWERP) $(MY_TWERP_OPTIONS) `find test -name '*_test.coffee'`

coverage: $(JS)
	istanbul cover $(TWERP) `find test -name '*_test.js'`

clean:
	@rm -vfr $(JS) coverage

.PHONY: clean test coverage dev
