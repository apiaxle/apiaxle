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
  cd /app/apiaxle/repl
  NODE_ENV=production coffee /app/apiaxle/repl/apiaxle.coffee
elif [ $app = 'test' ]; then
  apk add --update make
  cd /app/apiaxle
  make
  make test
else
  cd /app/apiaxle/$app
  NODE_ENV=production coffee /app/apiaxle/$app/apiaxle-$app.coffee -h 0.0.0.0 -p $port -f 1
fi
