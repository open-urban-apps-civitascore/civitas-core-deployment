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

# Run pre-commit on all files
validate:
	pre-commit run --all-files;

# Deploy locally using minikube and local environment
deploy-local:
	$(MAKE) deploy-minikube namespace=local-civitas2
	helmfile -f ./helmfile.d/ sync -e local --kube-context minikube

# Deploy locally using minikube and default environment
deploy-default:
	$(MAKE) deploy-minikube namespace=main-civitas2
	helmfile -f ./helmfile.d/ sync -e default --kube-context minikube

# Update local
sync-local:
	helmfile -f ./helmfile.d/ sync -e local --kube-context minikube

# Update default
sync-default:
	helmfile -f ./helmfile.d/ sync -e default --kube-context minikube

# Deploy minikube
deploy-minikube:
	@echo "Starting minikube and deploying to namespace: $(namespace)"
	minikube start --cpus=4 --memory=8192
	minikube addons enable metrics-server
	minikube addons enable ingress

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
