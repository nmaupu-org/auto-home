default: push
.PHONY: default clean build tag tag-latest check-docker-hub

NAME=job
VERSION=1.0.0
REMOTE_NAME=$(DOCKER_ID_USER)/$(NAME)

ARCH=amd64
PLATFORM=linux

build: check-docker-hub
	docker build -t $(NAME):$(VERSION) .
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
