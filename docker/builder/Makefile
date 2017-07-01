default: push
.PHONY: default clean build tag tag-latest check-docker-hub

NAME=builder
VERSION=1.0
REMOTE_NAME=$(DOCKER_ID_USER)/$(NAME)

# As of 2017/07/01, coreos/matchbox is working with terraform 0.9.6 max
TERRAFORM_VERSION=0.9.6

build: check-docker-hub clean tmp
	wget --no-check-certificate -O tmp/terraform.zip https://releases.hashicorp.com/terraform/$(TERRAFORM_VERSION)/terraform_$(TERRAFORM_VERSION)_linux_amd64.zip
	unzip -d tmp tmp/terraform.zip
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
