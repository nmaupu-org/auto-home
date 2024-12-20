default: push
.PHONY: default clean build tag tag-latest check-docker-hub

NAME=argocd-cmp-jsonnet
JB_VERSION=0.6.0
JSONNET_VERSION=0.20.0
VERSION=$(JSONNET_VERSION)
REMOTE_NAME=$(DOCKER_ID_USER)/$(NAME)

build: check-docker-hub
	docker build \
		--build-arg JB_VERSION=$(JB_VERSION) \
		--build-arg JSONNET_VERSION=$(JSONNET_VERSION) \
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
