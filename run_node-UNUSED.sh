#!/bin/sh
set -e

# ------------------------------------------------------------------
# Basic environment validation (unchanged)
# ------------------------------------------------------------------
if [ -n "${ETH_CLIENT_ADDRESS}" ]; then
  echo "ETH_CLIENT_ADDRESS variable was renamed to RLN_RELAY_ETH_CLIENT_ADDRESS"
  echo "Please update your .env file"
  exit 1
fi

if [ -z "${RLN_RELAY_ETH_CLIENT_ADDRESS}" ]; then
  echo "Missing Eth client address, please refer to README.md for detailed instructions"
  exit 1
fi

# ------------------------------------------------------------------
# Detect public IP (used for NAT)
# ------------------------------------------------------------------
MY_EXT_IP=$(wget -qO- https://api4.ipify.org)

# ------------------------------------------------------------------
# TLS – disabled (private network)
# ------------------------------------------------------------------
DISABLE_TLS=true

# ------------------------------------------------------------------
# Optional node key
# ------------------------------------------------------------------
if [ -n "${NODEKEY}" ]; then
  NODEKEY="--nodekey=${NODEKEY}"
fi

# ------------------------------------------------------------------
# Pick the binary that exists in the image (wakunode)
# ------------------------------------------------------------------
if [ -x /usr/bin/wakunode ]; then
  BINARY="/usr/bin/wakunode"
else
  echo "❌ No wakunode binary found in the image."
  exit 1
fi

# ------------------------------------------------------------------
# EXECUTE flags
# ------------------------------------------------------------------
exec "$BINARY" \
  --relay=true \
  --rln-relay=false 
  --filter=true \
  --lightpush=true \
  --keep-alive=true \
  --max-connections=150 \
  --discv5-discovery=true \
  --discv5-udp-port=9005 \
  --log-level=INFO \
  --tcp-port=30304 \
  --metrics-server=true \
  --metrics-server-address=0.0.0.0 \
  --metrics-server-port=${METRICS_PORT:-8008} \
  --rest=true \
  --rest-address=0.0.0.0 \
  --rest-port=8645 \
  --websocket-port=60000 \
  --websocket-support=true \
  --websocket-secure-support=false \
  --nat=extip:"${MY_EXT_IP}" \
  --store=true \
  --store-message-db-url="postgres://${POSTGRES_USER}:${POSTGRES_PASSWORD}@postgres:5432/postgres" \
  ${NODEKEY} \
  ${EXTRA_ARGS}
