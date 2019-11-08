default: push
.PHONY: default clean build tag tag-latest check-docker-hub

NAME=builder
VERSION=1.1
REMOTE_NAME=$(DOCKER_ID_USER)/$(NAME)

KUBECTL_VERSION=1.16.2

ARCH=amd64
PLATFORM=linux

build: check-docker-hub
	docker build --build-arg KUBECTL_VERSION=$(KUBECTL_VERSION) -t $(NAME):$(VERSION) .
	$(MAKE) clean

tag: build
	docker tag $(NAME):$(VERSION) $(REMOTE_NAME):$(VERSION)

tag-latest: push
	docker tag $(REMOTE_NAME):$(VERSION) $(REMOTE_NAME):latest
	docker push $(REMOTE_NAME):latest

push: tag
	docker push $(REMOTE_NAME):$(VERSION)

tmp:
	mkdir -p tmp

clean:
	rm -rf tmp

check-docker-hub:
ifndef DOCKER_ID_USER
	$(error ERROR! DOCKER_ID_USER environment variable must be defined)
endif
