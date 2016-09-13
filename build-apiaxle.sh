#!/bin/sh

cd /app/apiaxle && make clean && make && \

cd /app/apiaxle/base && npm install && \
ln -s /app/apiaxle/base node_modules/apiaxle-base && \

mv node_modules /app/apiaxle/api/ && \
cd /app/apiaxle/api && \
npm install && \
ln -s /app/apiaxle/api node_modules/apiaxle-api && \

mv node_modules /app/apiaxle/proxy/ && \
cd /app/apiaxle/proxy && \
npm install && \

mv node_modules /app/apiaxle/repl/ && \
cd /app/apiaxle/repl && \
npm install && \
echo "#!/usr/bin/env node" > apiaxle && cat ./apiaxle.js >> apiaxle && \
chmod a+x apiaxle && ln -s /app/apiaxle/repl/apiaxle /usr/bin/apiaxle && \

mv node_modules /app/
