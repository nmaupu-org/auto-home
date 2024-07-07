default: push
.PHONY: default clean build tag tag-latest check-docker-hub

NAME=nzbget
# Version of nzbget image (which is also the version of this image)
VERSION=24.1
# Name of the git branch of tag for Extension-ExtendedUnrar
EXT_UNRAR_VERSION=v2.1
REMOTE_NAME=$(DOCKER_ID_USER)/$(NAME)

build: check-docker-hub
	docker build \
		--build-arg "NZBGET_IMAGE_VERSION=$(VERSION)" \
		--build-arg "EXT_UNRAR_VERSION=$(EXT_UNRAR_VERSION)" \
		-t $(NAME):$(VERSION) .

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
