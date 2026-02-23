# .DEFAULT_GOAL := help

# MINIKUBE_IP := $(shell minikube ip)
marker := 'MINIKUBE_HOSTS'
hosts := 'apicurio.civitas.test keycloak.civitas.test apisix.civitas.test kafka-ui.civitas.test'

default:
	@just --list

# Run pre-commit on all files
[group('test & lint')]
validate:
	pre-commit run --all-files;

# Deploy specific environment to minikube namespace
[group('deployment')]
deploy environment='local' namespace='dev':
	echo "Deploying environment: {{environment}} to minikube namespace: {{namespace}}"
	just _minikube {{namespace}}
	helmfile -f ./deployment/helmfile.yaml sync -e {{environment}}

# Update specific environment in minikube
[group('deployment')]
sync environment='local':
	echo "Syncing environment: {{environment}} to minikube"
	helmfile -f ./deployment/helmfile.yaml sync -e {{environment}}

# Deploy minikube
[group('deployment')]
_minikube namespace='dev':
	which minikube > /dev/null || (echo "Minikube CLI not found. Please install Minikube CLI first." && exit 1)
	echo "Starting minikube and deploying to namespace: {{namespace}}"
	minikube start --cpus=4 --memory=8192
	minikube addons enable metrics-server
	minikube addons enable ingress

	helm install \
		cert-manager oci://quay.io/jetstack/charts/cert-manager \
		--version v1.19.2 \
		--namespace cert-manager \
		--create-namespace \
		--set crds.enabled=true

	kubectl create namespace {{namespace}}

	kubectl create secret generic keycloak-smtp \
		--from-literal=host='smtp.example.com' \
		--from-literal=port='587' \
		--from-literal=from='noreply@example.com' \
		--from-literal=user='noreply@example.com' \
		--from-literal=password='YOUR_SMTP_PASSWORD' \
		-n {{namespace}}

# Deploy k3d
[group('deployment')]
deploy-k3d:
	which k3d > /dev/null || (echo "k3d CLI not found. Please install k3d CLI first." && exit 1)
	./dev-deployment/startup.sh -k

# Deploy linkerd
[group('deployment')]
linkerd:
	which linkerd > /dev/null || (echo "Linkerd CLI not found. Please install Linkerd CLI first." && exit 1)
	linkerd check --pre
	kubectl apply --server-side -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.4.0/standard-install.yaml
	linkerd install --crds | kubectl apply -f -
	linkerd install --set proxy.nativeSidecar=true | kubectl apply -f -
	linkerd check

# Add host entries to /etc/hosts for Linux systems
[group('helpers')]
[linux]
add-hosts:
	@if ! minikube status > /dev/null 2>&1; then \
		echo "Minikube is not running. Please start minikube first."; \
		exit 1; \
	fi
	@echo "Updating /etc/hosts with Minikube IP $(minikube ip)"
	@sudo sed -i.bak '/# {{marker}}/,/^$$/d' /etc/hosts
	@echo "# {{marker}}" | sudo tee -a /etc/hosts > /dev/null
	@for h in {{hosts}}; do \
		echo "$(minikube ip) $h" | sudo tee -a /etc/hosts > /dev/null ; \
	done
	@echo "" | sudo tee -a /etc/hosts > /dev/null
	@echo "Done."

# Add host entries to /etc/hosts for MacOS systems
[group('helpers')]
[macos]
add-hosts:
	@if ! minikube status > /dev/null 2>&1; then \
		echo "Minikube is not running. Please start minikube first."; \
		exit 1; \
	fi
	@echo "Updating /etc/hosts with 127.0.0.1"
	@sudo sed -i.bak '/# {{marker}}/,/^$$/d' /etc/hosts
	@echo "# {{marker}}" | sudo tee -a /etc/hosts > /dev/null
	@for h in {{hosts}}; do \
		echo "127.0.0.1 $h" | sudo tee -a /etc/hosts > /dev/null ; \
	done
	@echo "" | sudo tee -a /etc/hosts > /dev/null
	@echo "Done."

# Create a new platform component
[group('components')]
new-component:
	cd components && copier copy .. .

# Update platform components
[group('components')]
update:
	copier update --skip-answered -a test/.copier-answers.yaml components

# Update all components in the components/ directory
[group('components')]
update-components:
	@for d in components/*; do \
		if [ -d "$$d" ]; then \
			name=$$(basename "$$d"); \
			echo "Updating $$name..."; \
			( cd components && copier update --skip-answered --vcs-ref 8969ae22 -a "$$name/.copier-answers.yml" ) || echo "copier update failed for $$name"; \
		fi; \
	done;

# Verify Kyverno policies
[group('test & lint')]
verify-policies:
	.ci/policies/verify-kyverno-policies.sh

# Render helmfile for specific environment
[group('helpers')]
template environment='local':
	helmfile -f ./deployment/helmfile.yaml template -e {{environment}}
