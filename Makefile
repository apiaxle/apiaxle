dest=$(DESTDIR)/opt/apiaxle

install:
	install -d $(dest)
	cp -r api proxy base $(dest)

	# npm link the base directory
	for project in api proxy; do	\
    cd $$project;								\
    npm link ../base;						\
    cd ..;											\
  done
