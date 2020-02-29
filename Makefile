# https://www.gnu.org/software/make/manual/html_node/Makefile-Conventions.html

SHELL = /bin/bash

.SUFFIXES:

VERSION = latest

IMAGE = darrenleeweber/docker-python-3.6

.PHONY: git-version build clean history run shell push

git-version:
	git remote -v > version
	git log -n1 --pretty=format:'%h - %d %s <%an>' >> version
	echo >> version

build: git-version
	docker build -t $(IMAGE) .
	rm version

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

run: build
	docker run --rm -it $(IMAGE)

shell: build
	docker run --rm -it $(IMAGE) /bin/bash

push: build
	docker push darrenleeweber/docker-python-3.6:$(VERSION)

