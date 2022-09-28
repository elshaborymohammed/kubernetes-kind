#!/usr/bin/env make

.PHONY: run_website install_kind install_kubectl create_kind_cluster \
	create_docker_registry connect_registry_to_kind_network \
	connect_registry_to_kind create_kind_cluster_with_registry \
  install_ingress_controller install_app

install_kubectl:
	brew install kubectl || true;

install_kind:
	#curl -o ./kind https://github.com/kubernetes-sigs/kind/releases/download/v0.11.1/kind-darwin-arm64
	brew install kind || true;

install_k8s:
	$(MAKE) install_kubectl && $(MAKE) install_kind

run_website:
	docker build -t explorecalifornia.com . && \
		docker run -p 5000:80 -d --name explorecalifornia.com --rm explorecalifornia.com

build:
	echo "\033[1;33m>> build docker image \033[0m";
	docker build -t explorecalifornia.com .;
tag:
	echo "\033[1;33m>> tag image on docker local registry \033[0m";
	docker tag explorecalifornia.com localhost:6000/explorecalifornia.com;
push: build tag
	echo "\033[1;33m>> push image on docker local registry \033[0m";
	docker push localhost:6000/explorecalifornia.com;

connect_registry_to_kind_network:
	echo "\033[1;33m>>connect_registry_to_kind_network \033[0m"; \
	docker network connect kind local-registry || true;

connect_registry_to_kind: connect_registry_to_kind_network
	echo "\033[1;33m>> connect_registry_to_kind \033[0m"; \
	kubectl apply -f ./kind_configmap.yaml;

create_docker_registry:
	echo "\033[1;33m>> create_docker_registry \033[0m"; \
	if ! docker ps | grep -q 'local-registry'; \
	then docker run -d -p 6000:5000 --name local-registry --restart=always registry; \
	else echo "---> local-registry is already running. There's nothing to do here."; \
	fi

create_kind_cluster: create_docker_registry push
	echo "\033[1;33m>> create_kind_cluster \033[0m"; \
	kind create cluster --image=kindest/node:v1.21.12 --name explorecalifornia.com --config ./kind_config.yaml || true
	kubectl get nodes

install_cluster:
	$(MAKE) create_kind_cluster && $(MAKE) connect_registry_to_kind

install_ingress_controller:
	kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml && \
	sleep 5 && \
	kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=90s

install: install_cluster
	echo "\033[1;33m>> Helm create cluster \033[0m"; \
	helm upgrade --atomic --install explorecalifornia.com ./chart

uninstall:
	echo "\033[1;33m>> Stop containers \033[0m";
	docker container ls -q | xargs docker container stop;
	echo "\033[1;33m>> Prune containers \033[0m"; \
	docker container prune -f; 
	echo "\033[1;33m>> Prune volumes \033[0m"; \
	docker volume prune -f;
	echo "\033[1;33m>> Prune networks \033[0m"; \
	 docker network prune -f;

