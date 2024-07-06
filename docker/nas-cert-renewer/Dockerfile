# syntax=docker/dockerfile:1
FROM alpine/git:2.45.2 as build
WORKDIR /tmp
RUN git clone https://github.com/nmaupu/deploy-freenas.git --depth=1

FROM python:3.9.19-slim
COPY --from=build /tmp/deploy-freenas/deploy_freenas.py /bin/deploy_freenas.py

RUN pip install requests

CMD ["/bin/deploy_freenas.py"]
