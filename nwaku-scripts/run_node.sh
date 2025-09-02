#!/bin/sh
set -e

# -------------------------------------------------
# Environment‑derived flags (keep only the ones you need)
# -------------------------------------------------
RELAY_FLAG="${RELAY:-}"
FILTER_FLAG="${FILTER:-}"
STORE_FLAG="${STORE:-}"
LIGHTPUSH_FLAG="${LIGHTPUSH:-}"
DISCOVERY_FLAG="${DISCOVERY:-}"
PEER_EXCHANGE_FLAG="${PEER_EXCHANGE:-}"
STATIC_NODES_FLAG="${STATIC_NODES:-}"
BOOTSTRAP_NODES_FLAG="${BOOTSTRAP_NODES:-}"
RANDOM_PEERS_FLAG="${RANDOM_PEERS:-}"
MAX_PEERS_FLAG="${MAX_PEERS:-}"
# … add any other flags you really want …

# -------------------------------------------------
# Run the node – **no --metrics or --metrics-addr**
# -------------------------------------------------
exec "$NODE_BINARY" \
  ${RELAY_FLAG} \
  ${FILTER_FLAG} \
  ${STORE_FLAG} \
  ${LIGHTPUSH_FLAG} \
  ${DISCOVERY_FLAG} \
  ${PEER_EXCHANGE_FLAG} \
  ${STATIC_NODES_FLAG} \
  ${BOOTSTRAP_NODES_FLAG} \
  ${RANDOM_PEERS_FLAG} \
  ${MAX_PEERS_FLAG}