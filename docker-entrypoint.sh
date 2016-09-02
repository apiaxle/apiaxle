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
  node /app/apiaxle/repl/apiaxle.js
elif [ $app = 'test' ]; then
  apk add --update make

  cd /app/apiaxle/proxy
  npm install nock

  cd /app/apiaxle
  make
  make test
else
  cd /app/apiaxle/$app
  node /app/apiaxle/$app/apiaxle-$app.js -h 0.0.0.0 -p $port -f 1
fi
