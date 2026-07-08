#!/usr/bin/env bash
# =============================================================================
# create-demo-db.sh
#
# Creates the `demo` database + `demo` user in the deployment's Postgres cluster
# and imports the demo dataset (tests/03-demo.sql).
#
# Callable from:
#   * GitLab CI (nightly / smoke-test setup) — before system tests run.
#   * The `just create-demo-db` recipe (local dev), which delegates here so the
#     logic lives in a single place and needs no `just` in the CICD image.
#
# Usage:
#   ./scripts/ci/create-demo-db.sh [profile]
#     profile   the postgres namespace is now resolved from the running 
#               cluster (default: local)
#
# Required tools (all present in the CICD image): kubectl.
# Optional env: DEMO_DB_PASSWORD (demo user password, defaults to `secret`).
# =============================================================================
set -euo pipefail

PROFILE="${1:-local}"

NS=$(kubectl get pods --all-namespaces -l cnpg.io/cluster=postgres-cluster,cnpg.io/instanceRole=primary -o jsonpath='{.items[0].metadata.namespace}')

if [ -z "$NS" ]; then
    echo "ERROR: Primary Postgres pod not found in any namespace"
    exit 1
fi

echo "Creating demo database in namespace: $NS"

# Get postgres superuser username
POSTGRES_USER=$(kubectl get secret -n "$NS" postgres-cluster-superuser -o jsonpath='{.data.username}' | base64 -d)

# Use the primary pod (writes are not allowed on read-only replicas)
POD=$(kubectl get pods -n "$NS" -l cnpg.io/cluster=postgres-cluster,cnpg.io/instanceRole=primary -o jsonpath='{.items[0].metadata.name}')

echo "Using primary Postgres pod: $POD"

# Demo user password (override via DEMO_DB_PASSWORD, e.g. in CI)
DB_PASSWORD="${DEMO_DB_PASSWORD:-secret}"

# Create user and database
echo "Creating database user 'demo'..."
kubectl exec -n "$NS" "$POD" -c postgres -- psql -U "$POSTGRES_USER" -c "CREATE USER demo WITH PASSWORD '$DB_PASSWORD';" 2>/dev/null || echo "User 'demo' may already exist"

echo "Creating database 'demo' with owner 'demo'..."
kubectl exec -n "$NS" "$POD" -c postgres -- psql -U "$POSTGRES_USER" -c "CREATE DATABASE demo WITH OWNER demo;" 2>/dev/null || echo "Database 'demo' may already exist"

# Grant necessary permissions
echo "Granting permissions..."
kubectl exec -n "$NS" "$POD" -c postgres -- psql -U "$POSTGRES_USER" -d demo -c "GRANT ALL ON SCHEMA public TO demo;"

# Import SQL file
echo "Importing tests/03-demo.sql..."
cat tests/03-demo.sql | kubectl exec -i -n "$NS" "$POD" -c postgres -- psql -U "$POSTGRES_USER" -d demo

# Change ownership of the demo table to the demo user
echo "Updating ownership..."
kubectl exec -n "$NS" "$POD" -c postgres -- psql -U "$POSTGRES_USER" -d demo -c "ALTER TABLE public.demo_sensor_readings OWNER TO demo;"

echo "✓ Database 'demo' created and SQL imported successfully!"
echo "  Database: demo"
echo "  User: demo"
echo "  Password: $DB_PASSWORD"
# In-cluster connection URL (e.g. how the nifi pod reaches this db)
echo "  In-cluster URL: postgresql://demo:$DB_PASSWORD@postgres-cluster-rw.$NS.svc.cluster.local:5432/demo"
