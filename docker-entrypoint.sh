#!/bin/sh

port=3000
app='api'

if [ $# -gt 0 ]; then
  app=$1
fi
if [ $# -gt 1 ]; then
  port=$2
fi

if [ $app = 'repl' ]; then
  coffee --watch --compile /app/apiaxle/base/index.coffee /app/apiaxle/base &
  cd /app/apiaxle/repl
  exec env NODE_ENV=production coffee /app/apiaxle/repl/apiaxle.coffee
elif [ $app = 'test' ]; then
  cd /app/apiaxle
  make
  make test
else
  coffee --watch --compile /app/apiaxle/base/index.coffee /app/apiaxle/base &
  cd /app/apiaxle/$app
  exec env NODE_ENV=production supervisor --force-watch -x coffee -w "/app/apiaxle/$app,/app/apiaxle/base" -- /app/apiaxle/$app/apiaxle-$app.coffee -h 0.0.0.0 -p $port -f 1
fi
