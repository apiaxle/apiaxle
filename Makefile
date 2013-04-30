SUBS=base api proxy repl

all:
	@for sub in $(SUBS); do $(MAKE) -C $$sub $@ || exit 1; done

npminstall:
	@for sub in $(SUBS); do $(MAKE) -C $$sub $@ || exit 1; done

test:
	@for sub in $(SUBS); do $(MAKE) -C $$sub $@ || exit 1; done

clean:
	@for sub in $(SUBS); do $(MAKE) -C $$sub $@ || exit 1; done

coverage:
	@for sub in $(SUBS); do $(MAKE) -C $$sub $@ || exit 1; done

publish:
	@for sub in $(SUBS); do $(MAKE) -C $$sub $@ || exit 1; done

link:
	@for sub in $(SUBS); do $(MAKE) -C $$sub $@ || exit 1; done

.PHONY: test link publish coverage clean npminstall
