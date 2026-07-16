FROM wiremind/sshd

ARG PENNYVAT_BIN_PATH

RUN apk update
RUN apk add curl jq

## Tools

COPY ${PENNYVAT_BIN_PATH} /bin/pennyvat
RUN  chmod +x /bin/pennyvat
