.PHONY: docker-build docker-push

# Build the current source tree in a multi-stage Docker image.
# Usage:
#   make docker-build                  # builds as consent-loop:latest
#   make docker-build TAG=v0.1.0       # custom tag
TAG ?= latest
IMAGE ?= consent-loop

docker-build:
	docker build -t $(IMAGE):$(TAG) .

# Push to a registry. Set IMAGE to the full registry path, e.g.:
#   make docker-push IMAGE=ghcr.io/cladam/consent-loop TAG=v0.3.0
docker-push:
	docker push $(IMAGE):$(TAG)
