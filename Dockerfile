FROM mhart/alpine-node:4

ENV NODE_ENV production

COPY ./api/ /app/apiaxle/api/
COPY ./base/ /app/apiaxle/base/
COPY ./proxy/ /app/apiaxle/proxy/
COPY ./repl/ /app/apiaxle/repl/
COPY ./coffeelint.json /app/apiaxle/
COPY ./Makefile /app/apiaxle/
COPY ./build-apiaxle.sh /app/build-apiaxle.sh
COPY ./docker-entrypoint.sh /app/apiaxle/
COPY ./apiaxle-config.json /apiaxle-config.json

WORKDIR /app/apiaxle

RUN apk add --update alpine-sdk python python-dev && \
    npm install -g coffee-script && \
    /app/build-apiaxle.sh && \
    apk del --purge alpine-sdk python python-dev && \
    npm uninstall -g coffee-script

ENTRYPOINT ["/app/apiaxle/docker-entrypoint.sh"]
