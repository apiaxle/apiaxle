#!/bin/sh

mkdir -p /app/node_modules && \
  ln -s /app/node_modules /app/apiaxle/base/node_modules && \
  ln -s /app/node_modules /app/apiaxle/api/node_modules && \
  ln -s /app/node_modules /app/apiaxle/proxy/node_modules && \
  ln -s /app/node_modules /app/apiaxle/repl/node_modules && \
  cd /app/apiaxle/base && npm install && npm link /app/apiaxle/base && \
  cd /app/apiaxle/api && npm install && npm link /app/apiaxle/api  && \
  cd /app/apiaxle/proxy && npm install && \
  cd /app/apiaxle/base && make clean && make && \
  cd /app/apiaxle/api && make clean && make && \
  cd /app/apiaxle/proxy && make clean && make && \
  cd /app/apiaxle/repl && npm install && \
  cd /app/apiaxle/repl && make clean && make && \
  echo "#!/usr/bin/env node" > apiaxle && cat ./apiaxle.js >> apiaxle && \
  chmod a+x apiaxle && ln -s /app/apiaxle/repl/apiaxle /usr/bin/apiaxle
