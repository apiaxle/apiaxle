#!/bin/sh

BASEDIR=`pwd`

make clean && make && \

cd $BASEDIR/base && npm install && \
ln -s $BASEDIR/base node_modules/apiaxle-base && \

mv node_modules $BASEDIR/api/ && \
cd $BASEDIR/api && \
npm install && \
ln -s $BASEDIR/api node_modules/apiaxle-api && \

mv node_modules $BASEDIR/proxy/ && \
cd $BASEDIR/proxy && \
npm install && \

mv node_modules $BASEDIR/repl/ && \
cd $BASEDIR/repl && \
npm install && \
echo "#!/usr/bin/env node" > apiaxle && cat ./apiaxle.js >> apiaxle && \
chmod a+x apiaxle && ln -s $BASEDIR/repl/apiaxle /usr/local/bin/apiaxle && \

mv node_modules $BASEDIR/
