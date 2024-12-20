default: push
.PHONY: default clean build tag tag-latest check-docker-hub

NAME=argocd
VERSION=2.6.15
JB_VERSION=0.6.0
REMOTE_NAME=$(DOCKER_ID_USER)/$(NAME)

build: check-docker-hub
	docker build \
		--build-arg ARGOCD_VERSION=$(VERSION) \
		--build-arg JB_VERSION=$(JB_VERSION) \
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
