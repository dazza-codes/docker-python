# https://www.gnu.org/software/make/manual/html_node/Makefile-Conventions.html

SHELL = /bin/bash

.SUFFIXES:

VERSION = latest

DOCKER_VER = docker19.03
PY_VER ?= 3.6

IMAGE = dazzacodes/docker-python

.PHONY: build clean history run shell push update

# Auto-clean is disabled by leaving the value empty
AUTOCLEAN ?= 

clean:
	@IMAGES=$$(docker images | grep '$(IMAGE)' | awk '{print $$1 ":" $$2}')
	@if test -n "$${IMAGES}"; then \
		if test -n "$(AUTOCLEAN)"; then \
			docker rmi -f "$${IMAGES}" 2> /dev/null || true; \
			docker system prune -f; \
		else \
			echo "$${IMAGES}" | xargs -n1 -p -r docker rmi; \
			docker system prune; \
		fi; \
	fi

history: build
	docker history $(IMAGE)

update:
	./update.sh

build:
	docker build -f "$(PY_VER)/$(DOCKER_VER)/Dockerfile" -t $(IMAGE):$(PY_VER) .

run: build
	docker run --rm -it $(IMAGE):$(PY_VER)

shell: build
	docker run --rm -it $(IMAGE):$(PY_VER) /bin/bash

push: build
	docker login docker.io
	docker push $(IMAGE):$(PY_VER)
