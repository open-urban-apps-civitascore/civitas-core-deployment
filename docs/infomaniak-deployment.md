# Infomaniak Kubernetes Deployment Guide

## Context & Goal
The goal is to deploy the CIVITAS/CORE V2 platform onto a managed Kubernetes cluster hosted by Infomaniak for the Prototype Fund project. This documentation serves as a runbook and captures specific learnings, prerequisites, and steps required that deviate from or complement the standard `minikube` / `k3d` local development setups.

## Prerequisites & Cluster Setup
Unlike local development environments (which use scripts like `startup.sh`), a managed Infomaniak cluster requires some manual bootstrapping.

### 1. Node Pool Requirements
Infomaniak's managed Kubernetes provides a control plane, but you must manually provision a node pool (Instance Group) to run workloads.
- **Minimum for Production Profile:** At least 8 vCPUs and 32 GB RAM in total.
- **Recommended Setup:** 2x `A4-Ram16-Disk50-Perf1` instances (or `Disk80`). This provides high availability and sufficient storage for container images.

### 2. Missing Core Components (Ingress & Cert-Manager)
The default Infomaniak Kubernetes cluster does not come with an Ingress Controller or Cert-Manager pre-installed. These are strict requirements for CIVITAS/CORE to expose services and secure them with SSL.

**Installation Steps:**

1. **Install Ingress-Nginx:**
   ```bash
   helm upgrade --install ingress-nginx ingress-nginx \
     --repo https://kubernetes.github.io/ingress-nginx \
     --namespace ingress-nginx --create-namespace
   ```

2. **Install Cert-Manager:**
   ```bash
   helm install cert-manager oci://quay.io/jetstack/charts/cert-manager \
     --version v1.19.2 \
     --namespace cert-manager \
     --create-namespace \
     --set crds.enabled=true
   ```

3. **Configure ClusterIssuer:**
   Create a `cluster-issuer.yaml` file to configure Let's Encrypt for automatic SSL certificates:
   ```yaml
   apiVersion: cert-manager.io/v1
   kind: ClusterIssuer
   metadata:
     name: letsencrypt-prod
   spec:
     acme:
       server: https://acme-v02.api.letsencrypt.org/directory
       email: <YOUR_EMAIL>
       privateKeySecretRef:
         name: letsencrypt-prod
       solvers:
       - http01:
           ingress:
             ingressClassName: nginx
   ```
   Apply with `kubectl apply -f cluster-issuer.yaml`.

## Environment Configuration
Once the cluster prerequisites are met, create the environment configuration in the deployment repository.

1. **Create the environment directory:**
   ```bash
   mkdir -p deployment/environments/infomaniak
   ```

2. **Create the global configuration file:**
   Create `deployment/environments/infomaniak/global.yaml.gotmpl` with the following configuration:
   ```yaml
   global:
     domain: <your-domain.com>
     instanceSlug: infomaniak
     profile: production
     initialUserEmail: <your-email>
     ingress:
       clusterIssuer: 'letsencrypt-prod'
       ingressClass: 'nginx'
   ```

## Deployment Logbuch & Troubleshooting
*(Dokumentiert während des Live-Deployments am 25./29.06.2026)*

- **[Problem]** Beim Ausführen von `kubectl` Befehlen (`connection refused` auf `127.0.0.1`) zeigte der Kontext auf das falsche (lokale) Cluster.
  - *Lösung:* Kubeconfig von Infomaniak muss in der Terminal-Session entweder über die Umgebungsvariable `export KUBECONFIG=/path/to/kubeconfig` gesetzt oder explizit mit `--kubeconfig` bei jedem Befehl übergeben werden.
- **[Problem]** Zwei-Cluster-Falle bei der Nutzung von Terminals und k9s.
  - *Ursache:* Befehle wie `just sync infomaniak` fielen (ohne explizite KUBECONFIG) auf lokale Configs wie `~/.kube/config` zurück. Dadurch wurden Teile in ein lokales Cluster und Teile ins Infomaniak-Cluster installiert.
  - *Lösung:* **Best Practice:** Immer inline die Kubeconfig setzen: `KUBECONFIG=~/k8s/kubeconfigs/... just sync infomaniak` und `k9s` analog mit `--kubeconfig` Flag starten.
- **[Problem]** Während des Deployments hängen Pods: `postgres-cluster-3` bleibt auf `Pending`, `kafka-cluster-controllers` auf `ContainerCreating` und `kafka-broker` im `CrashLoopBackOff`.
  - *Ursache (Postgres):* `Insufficient cpu, Insufficient memory`. Die 2 Server (8 CPU / 32 GB RAM) sind komplett ausgelastet. Das `production` Profil fordert mehr Ressourcen an, als vorhanden sind.
  - *Lösung:* Wechsel in der `global.yaml.gotmpl` von `profile: production` auf `profile: development`, um die Anzahl der Replicas und den Ressourcenbedarf zu senken.
- **[Problem]** Zweiter Lauf von `just sync infomaniak` schlägt fehl mit `can't shrink existing storage from 50Gi to 1Gi` (und ähnliches bei ETCD mit `Forbidden: updates to statefulset spec`).
  - *Ursache:* Das `production` Profil hatte beim ersten Lauf bereits riesige Festplatten (z.B. 50 GB für Postgres) und StatefulSets angelegt. Das `development` Profil will diese verkleinern, was Kubernetes blockiert.
  - *Lösung:* Das alte StatefulSet und die dazugehörigen PVCs (Persistent Volume Claims) für Postgres, ETCD und Kafka in `k9s` löschen, damit Helmfile sie mit dem neuen Profil von Grund auf neu anlegen kann.
- **[Problem]** Deployment bricht bei `keycloak-config` nach exakt 5 Minuten mit einem Timeout ab (`context deadline exceeded`), Pod hängt im Status `CreateContainerConfigError`.
  - *Ursache:* Dem Konfigurations-Job fehlt das Secret `keycloak-smtp` (E-Mail-Zugangsdaten). Bei lokalen Test-Läufen legt der `just deploy` Shell-Wrapper dieses Secret automatisch als Dummy an, was beim manuellen `just sync` für Infomaniak fehlt.
  - *Lösung:* Das `keycloak-smtp` Secret manuell als Dummy-Secret anlegen:
    ```bash
    kubectl create secret generic keycloak-smtp \
      --from-literal=host='smtp.example.com' --from-literal=port='587' \
      --from-literal=from='noreply' --from-literal=user='noreply' \
      --from-literal=password='YOUR_SMTP_PASSWORD' -n infomaniak
    ```
- **[Problem]** Deployment bricht bei `nifi-nifi` mit Timeout ab. Der Pod bleibt dauerhaft auf `Init:0/2` hängen (`FailedAttachVolume`).
  - *Ursache:* Infomaniak-Cloud-Bug! Infomaniak verschluckt sich teilweise beim parallelen Erstellen der vielen NiFi-Festplatten. Die Festplatten hängen bei OpenStack im Status `creating` fest (`Invalid volume status`).
  - *Lösung:* Genau dasselbe Manöver wie bei ETCD: Das `nifi-nifi` StatefulSet und alle 6 dazugehörigen NiFi-PVCs in `k9s` löschen, um den Festplatten-Bestellvorgang bei Infomaniak neu auszulösen. Danach `just sync infomaniak` erneut ausführen.
- **[Problem]** "Volume Limit Exceeded" / Pendeleffekte beim Neuanlegen von PVCs. Helm bleibt hängen, weil keine Festplatten mehr erstellt werden können.
  - *Ursache:* Wenn man PVCs in k9s löscht, löscht OpenStack die physischen Festplatten im Hintergrund oft sehr verzögert. Kubernetes vergisst die PVCs sofort, aber bei OpenStack bleiben sie als "Verfügbar" (verwaist) liegen. Helm bestellt dann munter neue Platten, wodurch man sofort in das Cloud-Quota-Limit (z.B. max 20 Volumes) rennt.
  - *Lösung:* Einloggen in das **Infomaniak OpenStack Horizon Dashboard**. Unter Datenträger nach Status filtern. Alle Festplatten mit dem Status **"Verfügbar"** (NICHT "In Verwendung") markieren und manuell löschen, um das Limit wieder freizuräumen.
- **[Problem]** NiFi-Pod stürzt in einer Endlosschleife ab (`CrashLoopBackOff`) mit `java.net.http.HttpTimeoutException` auf der Keycloak `.well-known/openid-configuration` URL.
  - *Ursache:* Hairpin NAT. NiFi versucht Keycloak über die öffentliche Internet-URL (`https://idm.civitas-...`) zu erreichen, was vom externen Load Balancer blockiert/gedropped wird.
  - *Lösung:* Die öffentliche OIDC-URL in der Datei `components/nifi/values/nifi/base-values.yaml.gotmpl` (Zeile 11) durch die interne Kubernetes-Service-URL ersetzen: `oidc_url: 'http://keycloak-app-keycloakx-http.{{ $global.instanceSlug }}.svc:80/realms/{{ $global.instanceSlug }}/.well-known/openid-configuration'`.
- **[Problem]** Helm Sync für NiFi wurde ausgeführt, aber NiFi stürzt **weiterhin** mit der alten öffentlichen URL ab.
  - *Ursache:* NiFi persistiert seine Konfigurationsdatei (`nifi.properties`) beim ersten Start auf dem `config`-PVC. Ein Pod-Neustart oder Helm-Sync überschreibt diese Datei nicht, solange sie auf der Festplatte existiert.
  - *Lösung:* Um NiFi zur Nutzung der neuen ConfigMap zu zwingen, muss das `config-nifi-nifi-0` PVC in k9s gelöscht werden (nur unproblematisch bei Erstinstallation ohne Flows). Danach den Pod killen, damit ein frisches PVC erstellt wird und das Startup-Skript die Config neu aufbaut.
