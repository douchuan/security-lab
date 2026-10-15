#!/bin/bash
# Custom entrypoint for Wazuh Indexer that auto-initializes security on first run.
# Starts opensearch via the original entrypoint in background, runs securityadmin, then foregrounds.

set -e

SECURITY_MARKER="/var/lib/wazuh-indexer/.security_initialized"

if [ ! -f "$SECURITY_MARKER" ]; then
  echo "[entrypoint] Starting OpenSearch in background for security init..."

  # Start the original entrypoint in the background (it will start opensearch)
  /entrypoint.sh opensearchwrapper &
  OPENSEARCH_PID=$!

  # Wait for OpenSearch to accept connections (up to 90s)
  echo "[entrypoint] Waiting for OpenSearch to be ready..."
  for i in $(seq 1 90); do
    if curl -sfk https://localhost:9200 > /dev/null 2>&1; then
      echo "[entrypoint] OpenSearch is ready (attempt $i)"
      break
    fi
    if ! kill -0 $OPENSEARCH_PID 2>/dev/null; then
      echo "[entrypoint] ERROR: OpenSearch process exited unexpectedly"
      exit 1
    fi
    echo "[entrypoint] Waiting... ($i/90)"
    sleep 1
  done

  echo "[entrypoint] Running securityadmin.sh..."
  export JAVA_HOME=/usr/share/wazuh-indexer/jdk
  export PATH=$JAVA_HOME/bin:$PATH

  /usr/share/wazuh-indexer/plugins/opensearch-security/tools/securityadmin.sh \
    -cacert /usr/share/wazuh-indexer/config/certs/root-ca.pem \
    -cert /usr/share/wazuh-indexer/config/certs/admin.pem \
    -key /usr/share/wazuh-indexer/config/certs/admin-key.pem \
    -cd /usr/share/wazuh-indexer/config/opensearch-security/ \
    -icl \
    -p 9200 \
    -nhnv

  touch "$SECURITY_MARKER"
  echo "[entrypoint] Security initialization complete"
  echo "[entrypoint] Bringing OpenSearch to foreground (PID: $OPENSEARCH_PID)"
  wait $OPENSEARCH_PID
else
  echo "[entrypoint] Security already initialized, starting normally"
  exec /entrypoint.sh "$@"
fi
