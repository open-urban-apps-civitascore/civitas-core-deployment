# .DEFAULT_GOAL := help

set dotenv-load

# MINIKUBE_IP := $(shell minikube ip)
marker := 'LOCAL_CIVITAS_HOSTS'
hosts := 'idm.civitas.test portal.civitas.test api.civitas.test dashboard.civitas.test'

default:
	@just --list

# Run pre-commit on all files
[group('test & lint')]
validate:
	pre-commit run --all-files;

# Sync a specific component in an environment
[group('deployment')]
sync-component environment='local' component='':
	echo "Syncing component: {{component}} in environment: {{environment}}"
	helmfile -f ./deployment/helmfile.yaml sync -e {{environment}} --selector component={{component}}

# Destroy a specific component in an environment
[group('deployment')]
destroy-component environment='local' component='':
	echo "Destroying component: {{component}} in environment: {{environment}}"
	helmfile -f ./deployment/helmfile.yaml destroy -e {{environment}} --selector component={{component}}

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
sync environment='local' component='all':
	if [ "{{component}}" = "all" ]; then \
		echo "Syncing environment: {{environment}}"; \
		helmfile -f ./deployment/helmfile.yaml sync -e {{environment}}; \
	else \
		echo "Syncing component: {{component}} in environment: {{environment}}"; \
		helmfile -f ./deployment/helmfile.yaml sync -e {{environment}} --selector component={{component}}; \
	fi

# Deploy linkerd
[group('deployment')]
linkerd:
	just _check-dependencies linkerd
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
	done

# Verify Kyverno policies
[group('test & lint')]
verify-policies:
	.ci/policies/verify-kyverno-policies.sh

# Render helmfile for specific environment
[group('helpers')]
template environment='local' component='all':
	if [ "{{component}}" = "all" ]; then \
		echo "Rendering helmfile for environment: {{environment}}"; \
		helmfile -f ./deployment/helmfile.yaml template -e {{environment}}; \
	else \
		echo "Rendering helmfile for component: {{component}} in environment: {{environment}}"; \
		helmfile -f ./deployment/helmfile.yaml template -e {{environment}} --selector component={{component}}; \
	fi

# Render helmfile for a specific component in an environment
[group('helpers')]
template-component environment='local' component='':
	helmfile -f ./deployment/helmfile.yaml template -e {{environment}} --selector component={{component}}

# Print APIsix admin password
[group('helpers')]
apisix-password:
	@kubectl --context minikube get secret -n dev apisix-admin-credentials -o jsonpath='{.data.admin}' | base64 -d && echo

# Seed baseline platform data into the current cluster (kubectl context) or into the cluster behind the provided kubeconfig. The keycloak URL is required (no default — depends on the target cluster). The seed input defaults to the standard civitas baseline export. Other tunables (AUTH_USER, AUTH_PASSWORD, NAMESPACE, …) are still read from the top-level `.env` (loaded automatically via `set dotenv-load`). Job + credentials Secret are cleaned up after the run.
[group('deployment')]
seed keycloak-url kubeconfig='' seed-input='exports/1bf03aa3-3d9a-4291-8589-b888aa684c05.json':
	#!/usr/bin/env bash
	set -euo pipefail
	export KEYCLOAK_URL="{{keycloak-url}}"
	export SEED_INPUT="{{seed-input}}"
	args=()
	if [ -n "{{kubeconfig}}" ]; then
		args+=(--kubeconfig "{{kubeconfig}}")
	elif [ -n "${KUBECONFIG:-}" ]; then
		args+=(--kubeconfig "${KUBECONFIG}")
	fi
	exec ./scripts/ci/seed-platform-data.sh "${args[@]}"

# Deploy to local minikube or k3d cluster with Linkerd service mesh
[group('deployment')]
deploy cri='k3d' namespace='dev' profile='local':
	@if [ "{{cri}}" = "k3d" ]; then \
		just _check-dependencies k3d || exit 1; \
		./dev-deployment/startup.sh -k; \
	else if [ "{{cri}}" = "minikube" ]; then \
		just _check-dependencies minikube || exit 1; \
		./dev-deployment/startup.sh -m; \
	else \
		echo "Invalid container runtime interface (CRI) specified. Use 'k3d' or 'minikube'."; \
		exit 1; \
	fi; fi
	@just linkerd
	@if [ ! -d "./deployment" ]; then \
		cp -r defaults/deployment deployment; \
	fi
	@( timeout 30 bash -c 'until kubectl get ns {{namespace}} >/dev/null 2>&1; do sleep 1; done'; \
	kubectl create secret generic keycloak-smtp \
		--from-literal=host='smtp.example.com' \
		--from-literal=port='587' \
		--from-literal=from='noreply@example.com' \
		--from-literal=user='noreply@example.com' \
		--from-literal=password='YOUR_SMTP_PASSWORD' \
		-n {{namespace}} ) &
	@helmfile -f deployment/helmfile.yaml sync -e {{profile}}

# Remove local cluster
[group('deployment')]
destroy:
	@./dev-deployment/startup.sh -u

# Check for dependencies
[group('helpers')]
_check-dependencies dependencies='k3d':
	#!/usr/bin/env bash
	set -euo pipefail
	RED='\033[0;31m'
	NC='\033[0m' # No Color
	dependencies="docker kubectl helm helmfile linkerd openssl gettext"
	for dep in $dependencies; do
		if ! which $dep > /dev/null 2>&1; then
			echo -e "${RED}ERROR: $dep not found. Please install $dep first.${NC}"
			exit 1
		fi
	done
	if ! which {{dependencies}} > /dev/null 2>&1; then
		echo -e "${RED}ERROR: {{dependencies}} not found. Please install {{dependencies}} first.${NC}"
		exit 1
	fi
	if ! helm diff version > /dev/null 2>&1; then
		echo -e "${RED}ERROR: Helm Diff plugin not found. Please install Helm Diff plugin first.${NC}"
		exit 1
	fi

# Install dependencies
[group('helpers')]
[linux]
install-dependencies:
	if ! which docker > /dev/null; then \
		curl -fsSL https://get.docker.com -o get-docker.sh; \
		sh get-docker.sh; \
		sudo usermod -aG docker $USER; \
		newgrp docker; \
		rm get-docker.sh; \
	else \
		echo "Docker is already installed."; \
	fi
	if ! which kubectl > /dev/null; then \
		curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"; \
		sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl; \
	else \
		echo "kubectl is already installed."; \
	fi
	if ! which helm > /dev/null; then \
		curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash; \
		helm plugin install https://github.com/databus23/helm-diff; \
	else \
		echo "Helm is already installed."; \
	fi
	if ! which helmfile > /dev/null; then \
		curl -LO https://github.com/helmfile/helmfile/releases/download/v1.2.3/helmfile_1.2.3_linux_amd64.tar.gz; \
		tar -xzf helmfile_1.2.3_linux_amd64.tar.gz && sudo install -o root -g root -m 0755 helmfile /usr/local/bin/helmfile; \
		rm helmfile_1.2.3_linux_amd64.tar.gz; \
	else \
		echo "Helmfile is already installed."; \
	fi
	if ! which linkerd > /dev/null; then \
		export LINKERD2_VERSION=edge-25.12.2; \
		curl --proto '=https' --tlsv1.2 -sSfL https://run.linkerd.io/install-edge | sh; \
		export PATH=$HOME/.linkerd2/bin:$PATH; \
		echo 'export PATH="$HOME/.linkerd2/bin:$PATH"' >> ~/.bashrc; \
		linkerd version; \
	else \
		echo "Linkerd is already installed."; \
	fi
	if ! which openssl > /dev/null; then \
		sudo apt-get update && sudo apt-get install -y openssl; \
	else \
		echo "OpenSSL is already installed."; \
	fi
	if ! which gettext > /dev/null; then \
		sudo apt-get update && sudo apt-get install -y gettext-base; \
	else \
		echo "gettext is already installed."; \
	fi
[macos]
install-dependencies:
	echo "Please check https://docs.core.civitasconnect.digital/docs_v2/Development/Deployment/local-deployment for required dependencies and adjust your system accordingly."

# Get Admin Credentials
[group('helpers')]
get-admin-credentials:
    NS=$(yq '.global.instanceSlug' defaults/environment/global.yaml); \
    APISIX_PASSWORD=$(kubectl get secret -n "$NS" apisix-admin-credentials -o jsonpath='{.data.admin}' | base64 -d && echo); \
    KEYCLOAK_USERNAME=$(yq '.global.initialUserEmail' defaults/environment/global.yaml | cut -d '@' -f 1); \
    KEYCLOAK_PASSWORD=$(kubectl get secret -n "$NS" keycloak-admin-user -o jsonpath='{.data.password}' | base64 -d && echo); \
    POSTGRES_USER=$(kubectl get secret -n "$NS" postgres-cluster-superuser -o jsonpath='{.data.username}' | base64 -d && echo); \
    POSTGRES_PASSWORD=$(kubectl get secret -n "$NS" postgres-cluster-superuser -o jsonpath='{.data.password}' | base64 -d && echo); \
    TESTUSER_USERNAME="test@$(yq '.global.domain' defaults/environment/global.yaml)"; \
    TESTUSER_PASSWORD="TestTest1234!"; \
    echo "APISix Admin Password: $APISIX_PASSWORD"; \
    echo "Keycloak Admin Username: $KEYCLOAK_USERNAME"; \
    echo "Keycloak Admin Password: $KEYCLOAK_PASSWORD"; \
    echo "Postgres User: $POSTGRES_USER"; \
    echo "Postgres Password: $POSTGRES_PASSWORD"; \
    echo "Test User Username: $TESTUSER_USERNAME"; \
    echo "Test User Password: $TESTUSER_PASSWORD"; \
    if kubectl get secret -n "$NS" devicemanagement-db-credentials >/dev/null 2>&1; then \
        DEVICEMGMT_USER=$(kubectl get secret -n "$NS" devicemanagement-db-credentials -o jsonpath='{.data.username}' | base64 -d && echo); \
        DEVICEMGMT_PASSWORD=$(kubectl get secret -n "$NS" devicemanagement-db-credentials -o jsonpath='{.data.password}' | base64 -d && echo); \
        echo "Device-Management DB User: $DEVICEMGMT_USER"; \
        echo "Device-Management DB Password: $DEVICEMGMT_PASSWORD"; \
    fi

# Create device-management database and import test data
[group('helpers')]
create-device-management-db:
    #!/usr/bin/env bash
    set -euo pipefail

    # Read configuration from global.yaml
    NS=$(yq '.global.instanceSlug' defaults/environment/global.yaml)

    echo "Creating device-management database in namespace: $NS"

    # Get postgres credentials
    POSTGRES_USER=$(kubectl get secret -n "$NS" postgres-cluster-superuser -o jsonpath='{.data.username}' | base64 -d)
    POSTGRES_PASSWORD=$(kubectl get secret -n "$NS" postgres-cluster-superuser -o jsonpath='{.data.password}' | base64 -d)

    # Get postgres pod name
    POD=$(kubectl get pods -n "$NS" -l cnpg.io/cluster=postgres-cluster -o jsonpath='{.items[0].metadata.name}')

    if [ -z "$POD" ]; then
        echo "ERROR: Postgres pod not found in namespace $NS"
        exit 1
    fi

    echo "Using Postgres pod: $POD"

    # Generate password for devicemanagement user
    DB_PASSWORD=$(openssl rand -base64 32)

    # Create user and database
    echo "Creating database user 'devicemanagement'..."
    kubectl exec -n "$NS" "$POD" -c postgres -- psql -U "$POSTGRES_USER" -c "CREATE USER devicemanagement WITH PASSWORD '$DB_PASSWORD';" 2>/dev/null || echo "User 'devicemanagement' may already exist"

    echo "Creating database 'device-management' with owner 'devicemanagement'..."
    kubectl exec -n "$NS" "$POD" -c postgres -- psql -U "$POSTGRES_USER" -c "CREATE DATABASE \"device-management\" WITH OWNER devicemanagement;" 2>/dev/null || echo "Database 'device-management' may already exist"

    # Grant necessary permissions
    echo "Granting permissions..."
    kubectl exec -n "$NS" "$POD" -c postgres -- psql -U "$POSTGRES_USER" -d "device-management" -c "REVOKE ALL ON DATABASE \"device-management\" FROM PUBLIC;"
    kubectl exec -n "$NS" "$POD" -c postgres -- psql -U "$POSTGRES_USER" -d "device-management" -c "GRANT ALL ON DATABASE \"device-management\" TO devicemanagement;"
    kubectl exec -n "$NS" "$POD" -c postgres -- psql -U "$POSTGRES_USER" -d "device-management" -c "GRANT ALL ON SCHEMA public TO devicemanagement;"

    # Import SQL file
    echo "Importing tests/02-device-management.sql..."
    cat tests/02-device-management.sql | kubectl exec -i -n "$NS" "$POD" -c postgres -- psql -U "$POSTGRES_USER" -d "device-management"

    # Change ownership of all objects in public schema to devicemanagement user
    echo "Updating ownership of tables, views, and sequences..."
    kubectl exec -n "$NS" "$POD" -c postgres -- psql -U "$POSTGRES_USER" -d "device-management" -c "
        DO \$\$
        DECLARE
            r RECORD;
        BEGIN
            -- Transfer table ownership
            FOR r IN SELECT tablename FROM pg_tables WHERE schemaname = 'public'
            LOOP
                EXECUTE 'ALTER TABLE public.' || quote_ident(r.tablename) || ' OWNER TO devicemanagement';
            END LOOP;

            -- Transfer view ownership
            FOR r IN SELECT viewname FROM pg_views WHERE schemaname = 'public'
            LOOP
                EXECUTE 'ALTER VIEW public.' || quote_ident(r.viewname) || ' OWNER TO devicemanagement';
            END LOOP;

            -- Transfer sequence ownership
            FOR r IN SELECT sequence_name FROM information_schema.sequences WHERE sequence_schema = 'public'
            LOOP
                EXECUTE 'ALTER SEQUENCE public.' || quote_ident(r.sequence_name) || ' OWNER TO devicemanagement';
            END LOOP;
        END
        \$\$;"

    # Create Kubernetes secret with credentials
    echo "Creating Kubernetes secret 'devicemanagement-db-credentials'..."
    kubectl create secret generic devicemanagement-db-credentials \
        --from-literal=username=devicemanagement \
        --from-literal=password="$DB_PASSWORD" \
        --from-literal=database=device-management \
        --from-literal=host=postgres-cluster-rw \
        --from-literal=port=5432 \
        -n "$NS" \
        --dry-run=client -o yaml | kubectl apply -f -

    echo "✓ Database 'device-management' created and SQL imported successfully!"
    echo "  Database: device-management"
    echo "  User: devicemanagement"
    echo "  Password stored in secret: devicemanagement-db-credentials"

# Create test user in Keycloak
[group('helpers')]
create-test-user profile='local':
    #!/usr/bin/env bash
    set -euo pipefail

    # Read configuration from global.yaml
    NS=$(helmfile template -f deployment/helmfile.yaml -e local --selector component=keycloak --skip-deps -q | yq 'select(.kind == "StatefulSet") | .metadata.namespace')
    DOMAIN=$(yq '.global.domain' defaults/environment/global.yaml)
    REALM=$(yq '.global.instanceSlug' defaults/environment/global.yaml)
    TEST_EMAIL="test@$DOMAIN"
    TEST_PASSWORD="TestTest1234!"

    echo "Creating test user: $TEST_EMAIL in realm: $REALM"

    ADMIN_USER=$(yq '.global.initialUserEmail' defaults/environment/global.yaml | cut -d '@' -f 1)
    ADMIN_PASSWORD=$(kubectl get secret -n "$NS" keycloak-admin-user -o jsonpath='{.data.password}' | base64 -d)

    POD=$(kubectl get pods -n "$NS" -l app.kubernetes.io/name=keycloakx -o jsonpath='{.items[0].metadata.name}')

    if [ -z "$POD" ]; then
        echo "ERROR: Keycloak pod not found in namespace $NS"
        exit 1
    fi

    echo "Using Keycloak pod: $POD"

    kubectl exec -n "$NS" "$POD" -- bash -c "
        /opt/keycloak/bin/kcadm.sh config credentials \
            --server http://localhost:8080 \
            --realm master \
            --user '$ADMIN_USER' \
            --password '$ADMIN_PASSWORD' >/dev/null 2>&1

        # Check if user already exists
        USER_ID=\$(/opt/keycloak/bin/kcadm.sh get users -r '$REALM' -q username=test --fields id --format csv --noquotes 2>/dev/null | head -n1)

        if [ -n \"\$USER_ID\" ] && [ \"\$USER_ID\" != \"id\" ]; then
            echo 'User test already exists, updating...'
            /opt/keycloak/bin/kcadm.sh update users/\$USER_ID -r '$REALM' \
                -s enabled=true \
                -s emailVerified=true \
                -s firstName=Surname \
                -s lastName=Lastname \
                -s email='$TEST_EMAIL'

            /opt/keycloak/bin/kcadm.sh set-password -r '$REALM' \
                --userid \$USER_ID \
                --new-password '$TEST_PASSWORD'
        else
            echo 'Creating new user...'
            /opt/keycloak/bin/kcadm.sh create users -r '$REALM' \
                -s username=test \
                -s enabled=true \
                -s emailVerified=true \
                -s firstName=Surname \
                -s lastName=Lastname \
                -s email='$TEST_EMAIL'

            /opt/keycloak/bin/kcadm.sh set-password -r '$REALM' \
                --username test \
                --new-password '$TEST_PASSWORD'
        fi
    "

    echo "✓ Test user created/updated successfully!"
    echo "  Username: test"
    echo "  Email: $TEST_EMAIL"
    echo "  Password: $TEST_PASSWORD"
    echo "  Realm: $REALM"
