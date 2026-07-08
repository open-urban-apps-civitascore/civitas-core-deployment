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
# Optional env:
#   DEMO_DB_PASSWORD  demo user password (defaults to `secret`).
#   DEMO_DB_DOTENV    if set, the demo db connection details are written to this
#                     file as DEMO_DB_* variables (consumed by the system tests).
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
# In-cluster connection details (e.g. how the nifi pod reaches this db)
DEMO_DB_HOST="postgres-cluster-rw.$NS.svc.cluster.local"
DEMO_DB_PORT="5432"
DEMO_DB_USER="demo"
DEMO_DB_NAME="demo"
DEMO_DB_URL="postgresql://$DEMO_DB_USER:$DB_PASSWORD@$DEMO_DB_HOST:$DEMO_DB_PORT/$DEMO_DB_NAME"
echo "  In-cluster URL: $DEMO_DB_URL"

# Write connection details for downstream jobs (e.g. system tests)
if [ -n "${DEMO_DB_DOTENV:-}" ]; then
    echo "Writing demo db connection details to $DEMO_DB_DOTENV"
    cat > "$DEMO_DB_DOTENV" <<EOF
DEMO_DB_URL=$DEMO_DB_URL
DEMO_DB_HOST=$DEMO_DB_HOST
DEMO_DB_PORT=$DEMO_DB_PORT
DEMO_DB_USER=$DEMO_DB_USER
DEMO_DB_PASSWORD=$DB_PASSWORD
DEMO_DB_NAME=$DEMO_DB_NAME
EOF
fi
