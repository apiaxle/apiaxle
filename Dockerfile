FROM mhart/alpine-node:4

ENV NODE_ENV production

RUN npm install -g coffee-script
RUN apk add --update alpine-sdk python python-dev

WORKDIR /app
RUN mkdir /app/node_modules

COPY base/package.json /app/apiaxle/base/package.json
RUN ln -s /app/node_modules /app/apiaxle/base/node_modules
RUN cd /app/apiaxle/base && npm install && npm link /app/apiaxle/base

COPY api/package.json /app/apiaxle/api/package.json
RUN ln -s /app/node_modules /app/apiaxle/api/node_modules
RUN cd /app/apiaxle/api && npm install

COPY proxy/package.json /app/apiaxle/proxy/package.json
RUN ln -s /app/node_modules /app/apiaxle/proxy/node_modules
RUN cd /app/apiaxle/proxy && npm install

COPY ./api/ /app/apiaxle/api/
COPY ./base/ /app/apiaxle/base/
COPY ./proxy/ /app/apiaxle/proxy/
COPY ./repl/ /app/apiaxle/repl/
COPY ./coffeelint.json /app/apiaxle/
COPY ./docker-entrypoint.sh /app/apiaxle/
COPY ./Makefile /app/apiaxle/
RUN cd /app/apiaxle/base && make clean && make
RUN cd /app/apiaxle/api && make clean && make
RUN cd /app/apiaxle/proxy && make clean && make

COPY repl/package.json /app/apiaxle/repl/package.json
RUN ln -s /app/node_modules /app/apiaxle/repl/node_modules
RUN cd /app/apiaxle/repl && npm link /app/apiaxle/api && npm install

RUN apk del --purge alpine-sdk python python-dev
RUN npm uninstall -g coffee-script

ENTRYPOINT ["/app/apiaxle/docker-entrypoint.sh"]
