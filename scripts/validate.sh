
#!/usr/bin/env bash
set -Eeuo pipefail

# Always run from the repository root.
cd "$(dirname "${BASH_SOURCE[0]}")/.."

echo "==> Validating Docker Compose..."
docker compose config --quiet

echo "==> Validating Grafana dashboard JSON..."
python3 -m json.tool \
  grafana/dashboards/network-observability.json \
  > /dev/null

echo "==> Preparing Prometheus targets..."
targets_dir="$PWD/prometheus/targets"
temporary_dir=""

cleanup() {
  if [[ -n "$temporary_dir" ]]; then
    rm -rf "$temporary_dir"
  fi
}
trap cleanup EXIT

# CI does not have access to private local targets.
if [[ ! -f "$targets_dir/icmp.local.yml" ]]; then
  temporary_dir="$(mktemp -d)"
  sed 's/YOUR_ROUTER_IP/127.0.0.1/' \
    prometheus/targets/icmp.example.yml \
    > "$temporary_dir/icmp.local.yml"
  targets_dir="$temporary_dir"
fi

echo "==> Validating Prometheus configuration..."
docker run --rm \
  -v "$PWD/prometheus/prometheus.yml:/etc/prometheus/prometheus.yml:ro" \
  -v "$targets_dir:/etc/prometheus/targets:ro" \
  --entrypoint /bin/promtool \
  prom/prometheus \
  check config /etc/prometheus/prometheus.yml

echo "==> All configuration checks passed!"
