.PHONY: build debug all

BUILD_IMAGE ?= csuliuming/gko3-compile-env:v0.9

all: build upload
	

build:
	docker build -t $(BUILD_IMAGE) dockerfile

upload:
	docker push $(BUILD_IMAGE)
