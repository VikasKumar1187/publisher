SHELL_PATH = /bin/ash
SHELL = $(if $(wildcard $(SHELL_PATH)),/bin/ash,/bin/bash)

# =====================================================================================================================================================
# Define dependencies

GOLANG          := golang:1.21.5
ALPINE          := alpine:3.19
KIND            := kindest/node:v1.29.0
VAULT           := hashicorp/vault:1.15
ZIPKIN          := openzipkin/zipkin:2.24
TELEPRESENCE    := datawire/tel2:2.17.0
POSTGRES        := postgres:16.1

# GRAFANA         := grafana/grafana:10.2.0
# PROMETHEUS      := prom/prometheus:v2.48.0
# TEMPO           := grafana/tempo:2.3.0
# LOKI            := grafana/loki:2.9.0
# PROMTAIL        := grafana/promtail:2.9.0
# POSTGRES        := postgres:16.0-alpine3.18


KIND_CLUSTER    := publisher-cluster
NAMESPACE       := publisher-system
DEPLOYMENTNAME	:= jobs-pod
APP             := jobs
BASE_IMAGE_NAME := publisher/service
SERVICE_NAME    := jobs-api
VERSION         := 0.0.1
SERVICE_IMAGE   := $(BASE_IMAGE_NAME)/$(SERVICE_NAME):$(VERSION)
#VERSION        := "0.0.1-$(shell git rev-parse --short HEAD)"

# ==============================================================================
# Install dependencies

dev-gotooling:
	go install github.com/divan/expvarmon@latest
	go install github.com/rakyll/hey@latest
	go install honnef.co/go/tools/cmd/staticcheck@latest
	go install golang.org/x/vuln/cmd/govulncheck@latest
	go install golang.org/x/tools/cmd/goimports@latest

dev-brew-common:
	brew update
	brew tap hashicorp/tap
	brew list kind || brew install kind
	brew list kubectl || brew install kubectl
	brew list kustomize || brew install kustomize
	brew list pgcli || brew install pgcli
	brew list vault || brew install vault

dev-brew: dev-brew-common
# dosn't work - do manually
#brew list datawire/blackbird/telepresence || brew install datawire/blackbird/telepresence

dev-docker:
	docker pull $(GOLANG)
	docker pull $(ALPINE)
	docker pull $(KIND)
	docker pull $(VAULT)
	docker pull $(ZIPKIN)
	docker pull $(TELEPRESENCE)
	docker pull $(POSTGRES)

# docker pull $(GRAFANA)
# docker pull $(PROMETHEUS)
# docker pull $(TEMPO)
# docker pull $(LOKI)
# docker pull $(PROMTAIL)

# =====================================================================================================================================================

#
# RSA Keys
# 	To generate a private/public key PEM file.
# 	$ openssl genpkey -algorithm RSA -out private.pem -pkeyopt rsa_keygen_bits:2048
# 	$ openssl rsa -pubout -in private.pem -out public.pem

# OPA Playground
# 	https://play.openpolicyagent.org/
# 	https://academy.styra.com/
# 	https://www.openpolicyagent.org/docs/latest/policy-reference/
# =====================================================================================================================================================
# Build docker image/s from our source code
jobs-api:
	docker build -t $(SERVICE_IMAGE) --build-arg BUILD_REF="$(VERSION)" -f zarf/docker/dockerfile.jobs-api .

all: jobs-api
# =====================================================================================================================================================
# Bring up/down cluster
# Without telepresence
dev-up-local:
	kind create cluster \
		--image $(KIND) \
		--name $(KIND_CLUSTER) \
		--config zarf/k8s/dev/kind-config.yaml

	kubectl wait --timeout=120s --namespace=local-path-storage --for=condition=Available deployment/local-path-provisioner
	kind load docker-image $(TELEPRESENCE) --name $(KIND_CLUSTER)
	kind load docker-image $(POSTGRES) --name $(KIND_CLUSTER)

dev-down-local:
	kind delete cluster --name $(KIND_CLUSTER)

# With telepresence
dev-up: dev-up-local
	telepresence --context=kind-$(KIND_CLUSTER) helm install
	telepresence --context=kind-$(KIND_CLUSTER) connect

dev-down:
	telepresence quit -s
	kind delete cluster --name $(KIND_CLUSTER)

# =====================================================================================================================================================
dev-status:
	kubectl get nodes -o wide
	kubectl get svc -o wide
	kubectl get pods -o wide --watch --all-namespaces
# =====================================================================================================================================================
dev-load:
	kind load docker-image $(SERVICE_IMAGE) --name $(KIND_CLUSTER)

dev-apply:
	kustomize build zarf/k8s/dev/database | kubectl apply -f -
	kubectl rollout status --namespace=$(NAMESPACE) --watch --timeout=120s sts/database

	kustomize build zarf/k8s/dev/jobs | kubectl apply -f -
	kubectl wait pods --namespace=$(NAMESPACE) --selector app=$(APP) --for=condition=Ready

dev-restart:
	kubectl rollout restart deployment $(DEPLOYMENTNAME) --namespace=$(NAMESPACE)

dev-update: all dev-load dev-restart

dev-update-apply: all dev-load dev-apply

#temp target, will be removed later on
dev-vikas:
# kind load docker-image $(TELEPRESENCE) --name $(KIND_CLUSTER)
# telepresence --context=kind-$(KIND_CLUSTER) helm install
# telepresence --context=kind-$(KIND_CLUSTER) connect
	kind load docker-image $(POSTGRES) --name $(KIND_CLUSTER)

# =====================================================================================================================================================
dev-logs:
	kubectl logs --namespace=$(NAMESPACE) -l app=$(APP) --all-containers=true -f --tail=100 --max-log-requests=6 | go run app/tooling/logfmt/main.go -service=$(SERVICE_NAME)

dev-describe-deployment:
	kubectl describe deployment --namespace=$(NAMESPACE) $(DEPLOYMENTNAME)

dev-describe-jobs:
	kubectl describe pod --namespace=$(NAMESPACE) -l app=$(APP)

# =====================================================================================================================================================
run-local:
	go run app/services/jobs-api/main.go | go run app/tooling/logfmt/main.go -service=$(SERVICE_NAME)

run-local-help:
	go run .\app\services\jobs-api\main.go --help
	
test:
	go test ./... -count=1
	staticcheck ./...

tidy:
	go mod tidy
	go mod vendor


metrics-views:
	expvarmon -ports="$(SERVICE_NAME).$(NAMESPACE).svc.cluster.local:4000" -vars="build,requests,goroutines,errors,panics,mem:memstats.Alloc"

metrics-view-local:
	expvarmon -ports="localhost:4000" -vars="build,requests,goroutines,errors,panics,mem:memstats.Alloc"

test-endpoint:
	curl -il $(SERVICE_NAME).$(NAMESPACE).svc.cluster.local:3000/test

test-endpoint-local:
	curl -il localhost:3000/test

run-scratch:
	go run app/tooling/scratch/main.go

test-endpoint-auth:
	curl -il -H "Authorization: Bearer ${TOKEN}" $(SERVICE_NAME).$(NAMESPACE).svc.cluster.local:3000/test/auth

test-endpoint-auth-local:
	curl -il -H "Authorization: Bearer ${TOKEN}" localhost:3000/test/auth





liveness-local:
	curl -il http://localhost:4000/debug/liveness

liveness:
	curl -il http://$(SERVICE_NAME).$(NAMESPACE).svc.cluster.local:4000/debug/liveness

readiness-local:
	curl -il http://localhost:4000/debug/readiness

readiness:
	curl -il http://$(SERVICE_NAME).$(NAMESPACE).svc.cluster.local:4000/debug/readiness


pgcli-local:
	pgcli postgresql://postgres:postgres@localhost

pgcli:
	pgcli postgresql://postgres:postgres@database-service.$(NAMESPACE).svc.cluster.local