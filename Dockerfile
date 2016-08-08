FROM mhart/alpine-node:4
RUN npm install -g coffee-script twerp supervisor
RUN apk add --update alpine-sdk python python-dev

WORKDIR /app
RUN mkdir /app/node_modules

ADD base/package.json /app/apiaxle/base/package.json
RUN ln -s /app/node_modules /app/apiaxle/base/node_modules
RUN cd /app/apiaxle/base && npm install && npm link /app/apiaxle/base

ADD api/package.json /app/apiaxle/api/package.json
RUN ln -s /app/node_modules /app/apiaxle/api/node_modules
RUN cd /app/apiaxle/api && npm install

ADD proxy/package.json /app/apiaxle/proxy/package.json
RUN ln -s /app/node_modules /app/apiaxle/proxy/node_modules
RUN cd /app/apiaxle/proxy && npm install

ADD . /app/apiaxle
RUN cd /app/apiaxle/base && make clean && make
RUN cd /app/apiaxle/api && make clean && make
RUN cd /app/apiaxle/proxy && make clean && make

ADD repl/package.json /app/apiaxle/repl/package.json
RUN ln -s /app/node_modules /app/apiaxle/repl/node_modules
RUN cd /app/apiaxle/repl && npm link /app/apiaxle/api && npm install

RUN apk del --purge alpine-sdk python python-dev
RUN apk add --update make
ENTRYPOINT ["/app/apiaxle/docker-entrypoint.sh"]
