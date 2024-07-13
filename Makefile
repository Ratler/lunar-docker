ISO :=
PWD = $(shell pwd)

all: dockerize

dockerize:
	@if ! test -f $(ISO); then echo "ISO= not set to a valid ISO file"; exit 1; fi
	$(PWD)/dockerize-lunar.sh -i "$(ISO)" -e ci-lunar

ci-docker: dockerize 
	@echo "Building $@"
	docker build -t lunar-linux:$(shell date "+%Y-%m-%d-%s") --rm .

.PHONY: all dockerize ci-docker
