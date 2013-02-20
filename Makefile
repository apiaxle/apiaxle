dest="$(DESTDIR)/opt/apiaxle"
config_dest="$(DESTDIR)/etc/apiaxle"
bin_dest="$(DESTDIR)/usr/bin"

install:
	install -d "$(dest)"
	cp -r api proxy base $(dest)

  # copy a minimal configuration file
	install -d "$(config_dest)"
	cp -v "release/config/development.json" "$(config_dest)"

  # symlinks so that people can actually run things
	install -d "$(bin_dest)"

	ln -vfs "$(dest)/base/repl/apiaxle" $(bin_dest)

  # # create our own version of coffee trying to avoid stomping on any
  # # currently installed version
	ln -vfs "$(dest)/base/node_modules/coffee-script/bin/coffee" "$(bin_dest)/axle-coffee"

	for project in api proxy; do	                                        \
	  ln -vfs "$(dest)/$$project/apiaxle_$${project}.coffee" $(bin_dest); \
  done

  # # emulate an 'npm link' to the base directory
	for project in api proxy; do	                                          \
		rm -f "$(dest)/$$project/node_modules/apiaxle.base";                  \
    ln -vfs "$(dest)/base" "$(dest)/$$project/node_modules/apiaxle.base"; \
  done
