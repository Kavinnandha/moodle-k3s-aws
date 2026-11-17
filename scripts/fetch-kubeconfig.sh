#!/usr/bin/env bash
# Copy the k3s admin kubeconfig off the server node through SSM (no SSH, no
# port 22) and point it at the Elastic IP.
#
# Usage: scripts/fetch-kubeconfig.sh <server-instance-id> <server-public-ip> [region]
#   (the exact command is printed by: terraform output fetch_kubeconfig)
#
# Writes ./kubeconfig (gitignored, chmod 600).
#
# Note: SSM keeps command output in its history for a while. This is fine for
# a lab. In a real environment, create a scoped ServiceAccount or OIDC login
# instead of handing out the cluster-admin kubeconfig.
set -euo pipefail

ID=${1:?instance id}
IP=${2:?server public ip}
REGION=${3:-ap-south-1}
OUT=${OUT:-kubeconfig}

echo "Waiting for k3s to write its kubeconfig (first boot takes ~3-5 min)..."
for _ in $(seq 1 30); do
  CMD_ID=$(aws ssm send-command --region "$REGION" --instance-ids "$ID" \
    --document-name AWS-RunShellScript \
    --parameters 'commands=["cat /etc/rancher/k3s/k3s.yaml"]' \
    --query Command.CommandId --output text 2>/dev/null) || { sleep 10; continue; }

  aws ssm wait command-executed --region "$REGION" --command-id "$CMD_ID" --instance-id "$ID" 2>/dev/null || true
  CONTENT=$(aws ssm get-command-invocation --region "$REGION" --command-id "$CMD_ID" \
    --instance-id "$ID" --query StandardOutputContent --output text)

  if grep -q 'apiVersion' <<<"$CONTENT"; then
    umask 077
    printf '%s\n' "${CONTENT//https:\/\/127.0.0.1:6443/https://$IP:6443}" > "$OUT"
    echo "Wrote $OUT. Next:  export KUBECONFIG=\$PWD/$OUT && kubectl get nodes -o wide"
    exit 0
  fi
  sleep 10
done

echo "k3s kubeconfig not available yet. Check /var/log/k3s-bootstrap.log via:" >&2
echo "  aws ssm start-session --region $REGION --target $ID" >&2
exit 1
