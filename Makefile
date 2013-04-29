SUBS=base proxy api repl

npminstall:
	@for sub in $(SUBS); do $(MAKE) -C $$sub $@; done

test:
	@for sub in $(SUBS); do $(MAKE) -C $$sub $@; done

clean:
	@for sub in $(SUBS); do $(MAKE) -C $$sub $@; done

coverage:
	@for sub in $(SUBS); do $(MAKE) -C $$sub $@; done

publish:
	@for sub in $(SUBS); do $(MAKE) -C $$sub $@; done

link:
	@for sub in $(SUBS); do $(MAKE) -C $$sub $@; done

.PHONY: test link publish coverage clean npminstall
