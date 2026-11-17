#!/usr/bin/env bash
# Deploy the whole stack onto the k3s cluster that Terraform created.
#
# Usage (from the repo root, with KUBECONFIG pointing at the cluster):
#   MOODLE_HOST=$(terraform -chdir=terraform output -raw moodle_host) \
#   ACME_EMAIL=you@example.com \
#   ./scripts/deploy.sh
#
# Optional:
#   CLUSTER_ISSUER=letsencrypt-prod   (default: letsencrypt-staging, see k8s/cert-manager)
#   MOODLE_IMAGE=ghcr.io/<you>/moodle-coderunner:4.5
#
# Safe to re-run: Secrets are created only if missing, everything else is
# applied idempotently, and the install Job runs Moodle's upgrade on an
# existing site.
set -euo pipefail

: "${MOODLE_HOST:?set MOODLE_HOST (terraform output -raw moodle_host)}"
: "${ACME_EMAIL:?set ACME_EMAIL (used for the Lets Encrypt account and the Moodle admin)}"
CLUSTER_ISSUER="${CLUSTER_ISSUER:-letsencrypt-staging}"
MOODLE_IMAGE="${MOODLE_IMAGE:-ghcr.io/kavinnandha/moodle-coderunner:4.5}"
export MOODLE_HOST ACME_EMAIL CLUSTER_ISSUER MOODLE_IMAGE

CERT_MANAGER_VERSION="v1.21.3"
KPS_VERSION="93.3.1"

cd "$(dirname "$0")/.."

for bin in kubectl helm envsubst openssl; do
  command -v "$bin" >/dev/null || { echo "missing required tool: $bin" >&2; exit 1; }
done

# Only substitute our own variables. Shell-style $vars inside the manifests
# (e.g. "$MYSQL_ROOT_PASSWORD" in probes) are left untouched.
render() {
  # shellcheck disable=SC2016
  envsubst '${MOODLE_HOST} ${ACME_EMAIL} ${CLUSTER_ISSUER} ${MOODLE_IMAGE}' < "$1"
}

rand() { openssl rand -base64 32 | tr -dc 'A-Za-z0-9' | head -c 24; }

ensure_secret() {
  local ns=$1 name=$2; shift 2
  if kubectl -n "$ns" get secret "$name" >/dev/null 2>&1; then
    echo "secret $ns/$name exists, keeping it"
  else
    kubectl -n "$ns" create secret generic "$name" "$@"
  fi
}

echo "==> Namespaces"
kubectl apply -f k8s/namespaces.yaml

echo "==> Secrets (generated once, stored only in the cluster)"
ensure_secret moodle moodle-db \
  --from-literal=root-password="$(rand)" \
  --from-literal=password="$(rand)"
# Moodle's default password policy wants upper, lower, digit and a symbol.
ensure_secret moodle moodle-admin --from-literal=password="$(rand)Aa1#"
ensure_secret monitoring grafana-admin \
  --from-literal=admin-user=admin \
  --from-literal=admin-password="$(rand)"

echo "==> Helm repos"
helm repo add jetstack https://charts.jetstack.io --force-update >/dev/null
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts --force-update >/dev/null

echo "==> cert-manager $CERT_MANAGER_VERSION"
helm upgrade --install cert-manager jetstack/cert-manager \
  --namespace cert-manager --create-namespace \
  --version "$CERT_MANAGER_VERSION" \
  --set crds.enabled=true \
  --wait --timeout 10m
render k8s/cert-manager/cluster-issuers.yaml | kubectl apply -f -

echo "==> MySQL"
kubectl apply -f k8s/moodle/network-policies.yaml
kubectl apply -f k8s/moodle/mysql.yaml
kubectl -n moodle rollout status statefulset/mysql --timeout=10m

echo "==> Moodle install/upgrade Job"
render k8s/moodle/moodle.yaml | kubectl apply -f -
# The Deployment is applied above (it holds the ConfigMap/PVC/Service). Hold
# it at 0 replicas until the DB schema is ready so the web installer is never
# reachable.
kubectl -n moodle scale deployment/moodle --replicas=0
kubectl -n moodle delete job moodle-install --ignore-not-found --wait=true
render k8s/moodle/install-job.yaml | kubectl apply -f -
if ! kubectl -n moodle wait --for=condition=complete job/moodle-install --timeout=20m; then
  echo "install Job failed. Logs:" >&2
  kubectl -n moodle logs job/moodle-install --tail=50 >&2 || true
  exit 1
fi

echo "==> Moodle web + cron + Ingress"
kubectl -n moodle scale deployment/moodle --replicas=1
kubectl -n moodle rollout status deployment/moodle --timeout=10m
render k8s/moodle/cron.yaml | kubectl apply -f -
render k8s/moodle/ingress.yaml | kubectl apply -f -

echo "==> Jobe (CodeRunner sandbox)"
kubectl apply -f k8s/jobe/jobe.yaml
kubectl -n jobe rollout status deployment/jobe --timeout=10m

echo "==> kube-prometheus-stack $KPS_VERSION"
helm upgrade --install kps prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --version "$KPS_VERSION" \
  -f k8s/monitoring/kube-prometheus-stack-values.yaml \
  --wait --timeout 15m

echo
echo "Done."
echo
echo "  Moodle:   https://$MOODLE_HOST   (issuer: $CLUSTER_ISSUER)"
cat <<'EOF'
  Admin password:
    kubectl -n moodle get secret moodle-admin -o jsonpath='{.data.password}' | base64 -d

  Grafana:
    kubectl -n monitoring port-forward svc/kps-grafana 3000:80   # then http://localhost:3000
    kubectl -n monitoring get secret grafana-admin -o jsonpath='{.data.admin-password}' | base64 -d

  Certificate status:
    kubectl -n moodle get certificate
EOF
