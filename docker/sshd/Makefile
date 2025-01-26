default: push
.PHONY: default clean build tag tag-latest check-docker-hub

NAME=sshd
VERSION=1.0.1
# Copy the last qonta binary to local directory before building
QONTA_BIN_PATH ?= ./qonta
REMOTE_NAME=$(DOCKER_ID_USER)/$(NAME)

build: check-docker-hub
	docker build \
		--build-arg QONTA_BIN_PATH=$(QONTA_BIN_PATH) \
		-t $(NAME):$(VERSION) .
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
