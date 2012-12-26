dest=$(DESTDIR)/opt/apiaxle
config_dest="/etc/apiaxle"

install:
	install -d $(dest)
	cp -r api proxy base $(dest)

  # copy a configuration file
	install -d "/etc/apiaxle"
	cp "release/config/development.json" "/etc/apiaxle"

  # npm link the base directory
	cd $(dest)
	for project in api proxy; do	\
    cd $$project;								\
    npm link ../base;						\
    cd ..;											\
  done
