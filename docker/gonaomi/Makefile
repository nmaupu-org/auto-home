default: push
.PHONY: build tag push check-docker-hub

NAME=gonaomi
GONAOMI_VERSION=1.2
VERSION=$(GONAOMI_VERSION)
REMOTE_NAME=$(DOCKER_ID_USER)/$(NAME)

build: check-docker-hub
	docker build --build-arg GONAOMI_VERSION=$(GONAOMI_VERSION) -t $(NAME):$(VERSION) .
	$(MAKE) clean

tag: build
	docker tag $(NAME):$(VERSION) $(REMOTE_NAME):$(VERSION)

push: tag
	docker push $(REMOTE_NAME):$(VERSION)

check-docker-hub:
ifndef DOCKER_ID_USER
	$(error ERROR! DOCKER_ID_USER environment variable must be defined)
endif
