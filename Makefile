.DEFAULT_GOAL := help

.PHONY: help validate deploy-local deploy-default deploy-minikube sync-local sync-default add-hosts

MINIKUBE_IP := $(shell minikube ip)
MARKER := MINIKUBE_HOSTS
HOSTS := apicurio.civitas.test keycloak.civitas.test apisix.civitas.test kafka-ui.civitas.test

# Show this help message
help:
	@echo "Available targets:"
	@awk 'BEGIN {FS = ":"} \
		/^# / { desc = substr($$0, 3) } \
		/^[a-zA-Z_-]+:/ && desc { printf "  \033[36m%-15s\033[0m %s\n", $$1, desc; desc = "" }' $(MAKEFILE_LIST)

# deploy k3d cluster
deploy-k3d:
	./dev_deployment/startup.sh -k

# deploy linkerd (nor production ready, only for local deployment!)
linkerd:
	linkerd check --pre
	kubectl apply --server-side -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.4.0/standard-install.yaml
	linkerd install --crds | kubectl apply -f -
	linkerd install --set proxy.nativeSidecar=true | kubectl apply -f -
	linkerd check


# Run pre-commit on all files
validate:
	pre-commit run --all-files;

# Deploy locally using minikube and local environment
deploy-local:
	$(MAKE) deploy-minikube namespace=dev
	helmfile -f ./deployment/helmfile.yaml sync -e local --kube-context minikube

# Deploy locally using minikube and default environment
deploy-default:
	$(MAKE) deploy-minikube namespace=main-civitas2
	helmfile -f ./deployment/helmfile.yaml sync -e default --kube-context minikube

# Update local
sync-local:
	helmfile -f ./deployment/helmfile.yaml sync -e local --kube-context minikube

# Update default
sync-default:
	helmfile -f ./deployment/helmfile.yaml sync -e default --kube-context minikube

# Deploy minikube
deploy-minikube:
	@echo "Starting minikube and deploying to namespace: $(namespace)"
	minikube start --cpus=4 --memory=8192
	minikube addons enable metrics-server
	minikube addons enable ingress

	helm install \
		cert-manager oci://quay.io/jetstack/charts/cert-manager \
		--version v1.19.2 \
		--namespace cert-manager \
		--create-namespace \
		--set crds.enabled=true

	kubectl create namespace $(namespace)

	kubectl create secret generic keycloak-smtp \
		--from-literal=host='smtp.example.com' \
		--from-literal=port='587' \
		--from-literal=from='noreply@example.com' \
		--from-literal=user='noreply@example.com' \
		--from-literal=password='YOUR_SMTP_PASSWORD' \
		-n $(namespace)

# Add host entries to /etc/hosts for Linux systems
add-hosts-linux:
	@echo "Updating /etc/hosts with Minikube IP $(MINIKUBE_IP)"
	@sudo sed -i.bak '/# $(MARKER)/,/^$$/d' /etc/hosts
	@echo "# $(MARKER)" | sudo tee -a /etc/hosts > /dev/null
	@for h in $(HOSTS); do \
		echo "$(MINIKUBE_IP) $$h" | sudo tee -a /etc/hosts > /dev/null ; \
	done
	@echo "" | sudo tee -a /etc/hosts > /dev/null
	@echo "Done."

# Add host entries to /etc/hosts for MacOS systems
add-hosts-macos:
	@echo "Updating /etc/hosts with 127.0.0.1"
	@sudo sed -i.bak '/# $(MARKER)/,/^$$/d' /etc/hosts
	@echo "# $(MARKER)" | sudo tee -a /etc/hosts > /dev/null
	@for h in $(HOSTS); do \
		echo "127.0.0.1 $$h" | sudo tee -a /etc/hosts > /dev/null ; \
	done
	@echo "" | sudo tee -a /etc/hosts > /dev/null
	@echo "Done."

.PHONY: new-component
new-component:
	cd components && copier copy .. .

.PHONY: update
update:
	copier update --skip-answered -a test/.copier-answers.yaml components

.PHONY: update-components
update-components:
	@for d in components/*; do \
		if [ -d "$$d" ]; then \
			name=$$(basename "$$d"); \
			echo "Updating $$name..."; \
			( cd components && copier update --skip-answered --vcs-ref 8969ae22 -a "$$name/.copier-answers.yml" ) || echo "copier update failed for $$name"; \
		fi; \
	done;

.PHONY: verify-policies
verify-policies:
	.ci/policies/verify-kyverno-policies.sh
