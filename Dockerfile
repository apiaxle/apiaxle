FROM mhart/alpine-node:4.8.0

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

RUN apk add --update alpine-sdk ca-certificates python python-dev && \
    npm install -g coffee-script@1.6 && \
    /app/build-apiaxle.sh && \
    apk del --purge alpine-sdk python python-dev && \
    npm uninstall -g coffee-script@1.6

ENV NODE_EXTRA_CA_CERTS /etc/ssl/certs/ca-certificates.crt

ENTRYPOINT ["/app/apiaxle/docker-entrypoint.sh"]
