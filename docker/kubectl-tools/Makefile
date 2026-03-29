default: push
.PHONY: default clean build tag tag-latest push check-docker-hub

NAME=kubectl-tools
VERSION=1.32.0
REMOTE_NAME=$(DOCKER_ID_USER)/$(NAME)

ARCH=amd64
PLATFORM=linux

build: check-docker-hub
	docker build --build-arg KUBECTL_VERSION=v$(VERSION) -t $(NAME):$(VERSION) .

tag: build
	docker tag $(NAME):$(VERSION) $(REMOTE_NAME):$(VERSION)

tag-latest: push
	docker tag $(REMOTE_NAME):$(VERSION) $(REMOTE_NAME):latest
	docker push $(REMOTE_NAME):latest

push: tag
	docker push $(REMOTE_NAME):$(VERSION)

check-docker-hub:
ifndef DOCKER_ID_USER
	$(error ERROR! DOCKER_ID_USER environment variable must be defined)
endif
