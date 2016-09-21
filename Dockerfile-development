FROM mhart/alpine-node:4

ENV NODE_ENV development

RUN npm install -g coffee-script twerp supervisor
RUN apk add --update alpine-sdk python python-dev

WORKDIR /app/apiaxle

COPY ./api/ /app/apiaxle/api/
COPY ./base/ /app/apiaxle/base/
COPY ./proxy/ /app/apiaxle/proxy/
COPY ./repl/ /app/apiaxle/repl/
COPY ./coffeelint.json /app/apiaxle/
COPY ./Makefile /app/apiaxle/
COPY ./apiaxle-config.json /apiaxle-config.json
COPY ./docker-entrypoint.sh /app/apiaxle/
COPY ./build-apiaxle.sh /app/build-apiaxle.sh

RUN /app/build-apiaxle.sh

ENTRYPOINT ["/app/apiaxle/docker-entrypoint.sh"]
