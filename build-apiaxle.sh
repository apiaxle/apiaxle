#!/bin/sh
mkdir -p /app/node_modules && cd /app && \
  ln -s /app/apiaxle/base /app/node_modules/apiaxle-base && \
  ln -s /app/apiaxle/api /app/node_modules/apiaxle-api && \
  cp /app/apiaxle/base/package.json /app/ && npm install && \
  cp /app/apiaxle/api/package.json /app/ && npm install && \
  cp /app/apiaxle/proxy/package.json /app/ && npm install && \
  cp /app/apiaxle/repl/package.json /app/ && npm install && \
  cd /app/apiaxle && make clean && make && \
  cd /app/apiaxle/repl && \
  echo "#!/usr/bin/env node" > apiaxle && cat ./apiaxle.js >> apiaxle && \
  chmod a+x apiaxle && ln -s /app/apiaxle/repl/apiaxle /usr/bin/apiaxle
