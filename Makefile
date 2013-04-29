SUBS=base proxy api repl

test:
	@for sub in $(SUBS); do $(MAKE) -C $$sub $@; done

clean:
	@for sub in $(SUBS); do $(MAKE) -C $$sub $@; done

coverage:
	@for sub in $(SUBS); do $(MAKE) -C $$sub $@; done

publish:
	@for sub in $(SUBS); do $(MAKE) -C $$sub $@; done

.PHONY: test
