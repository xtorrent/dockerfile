.PHONY: build debug all

BUILD_IMAGE ?= csuliuming/gko3-compile-env:v1.1

all: build upload
	

build:
	docker build -t $(BUILD_IMAGE) dockerfile

upload:
	docker push $(BUILD_IMAGE)
