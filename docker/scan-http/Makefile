default: push
.PHONY: build tag push check-docker-hub

NAME=scan-http
VERSION=1.3
REMOTE_NAME=$(DOCKER_ID_USER)/$(NAME)

build: check-docker-hub
	docker build -t $(NAME):$(VERSION) .

tag: build
	docker tag $(NAME):$(VERSION) $(REMOTE_NAME):$(VERSION)

push: tag
	docker push $(REMOTE_NAME):$(VERSION)

check-docker-hub:
ifndef DOCKER_ID_USER
	$(error ERROR! DOCKER_ID_USER environment variable must be defined)
endif
