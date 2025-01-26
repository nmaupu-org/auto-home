FROM wiremind/sshd

ARG QONTA_BIN_PATH

RUN apk update
RUN apk add curl jq

## Tools

COPY ${QONTA_BIN_PATH} /bin/qonta
RUN  chmod +x /bin/qonta
