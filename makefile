run-local:
	go run .\app\services\jobs-api\main.go

run-local-help:
	go run .\app\services\jobs-api\main.go --help
	
test:
	go test ./... -count=1
	staticcheck ./...

tidy:
	go mod tidy
	go mod vendor


# =====================================================================================================================================================
# Define dependencies

GOLANG          := golang:1.21
ALPINE          := alpine:3.18
KIND            := kindest/node:v1.28.0
POSTGRES        := postgres:16.0-alpine3.18
ZIPKIN          := openzipkin/zipkin:2.24

TELEPRESENCE    := datawire/tel2:2.13.1
VAULT           := hashicorp/vault:1.13

KIND_CLUSTER    := publisher-cluster
NAMESPACE       := publisher-system
DEPLOYMENTNAME	:= jobs-pod
APP             := jobs
BASE_IMAGE_NAME := publisher/service
SERVICE_NAME    := jobs-api
VERSION         := 0.0.1
SERVICE_IMAGE   := $(BASE_IMAGE_NAME)/$(SERVICE_NAME):$(VERSION)
#VERSION        := "0.0.1-$(shell git rev-parse --short HEAD)"

# =====================================================================================================================================================
# Build docker image/s from our source code
jobs-api:
	docker build --progress=plain -t $(SERVICE_IMAGE) --build-arg BUILD_REF="$(VERSION)" -f zarf/docker/dockerfile.jobs-api .

all: jobs-api
# =====================================================================================================================================================
# Bring up/down cluster
dev-up-local:
	kind create cluster \
		--image $(KIND) \
		--name $(KIND_CLUSTER) \
		--config zarf/k8s/dev/kind-config.yaml

	kubectl wait --timeout=120s --namespace=local-path-storage --for=condition=Available deployment/local-path-provisioner

dev-up: dev-up-local


dev-down-local:
	kind delete cluster --name $(KIND_CLUSTER)

dev-down: dev-down-local
# =====================================================================================================================================================
dev-status:
	kubectl get nodes -o wide
	kubectl get svc -o wide
	kubectl get pods -o wide --watch --all-namespaces
# =====================================================================================================================================================
dev-load:
	kind load docker-image $(SERVICE_IMAGE) --name $(KIND_CLUSTER)

dev-apply:
	kustomize build zarf/k8s/dev/jobs | kubectl apply -f -
	kubectl wait pods --namespace=$(NAMESPACE) --selector app=$(APP) --for=condition=Ready

dev-restart:
	kubectl rollout restart deployment $(DEPLOYMENTNAME) --namespace=$(NAMESPACE)

dev-update: all dev-load dev-restart

dev-update-apply: all dev-load dev-apply

# =====================================================================================================================================================
dev-logs:
	kubectl logs --namespace=$(NAMESPACE) -l app=$(APP) --all-containers=true -f --tail=100 --max-log-requests=6

dev-describe-deployment:
	kubectl describe deployment --namespace=$(NAMESPACE) $(DEPLOYMENTNAME)

dev-describe-jobs:
	kubectl describe pod --namespace=$(NAMESPACE) -l app=$(APP)