SUBS=base proxy api repl

test:
	for sub in $(SUBS); do \
	  $(MAKE) -C $$sub $@; \
  done

.PHONY: test
