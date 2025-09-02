#!/bin/sh
set -e

# ------------------------------------------------------------
# Basic env‑validation (unchanged)
# ------------------------------------------------------------
if [ -n "${ETH_CLIENT_ADDRESS}" ]; then
  echo "ETH_CLIENT_ADDRESS variable was renamed to RLN_RELAY_ETH_CLIENT_ADDRESS"
  echo "Please update your .env file"
  exit 1
fi

if [ -z "${RLN_RELAY_ETH_CLIENT_ADDRESS}" ]; then
  echo "Missing Eth client address, please refer to README.md for detailed instructions"
  exit 1
fi

# ------------------------------------------------------------
# Detect public IP (used for NAT)
# ------------------------------------------------------------
MY_EXT_IP=$(wget -qO- https://api4.ipify.org)

# ------------------------------------------------------------
# TLS / Let's Encrypt – disabled for this demo (private network)
# ------------------------------------------------------------
DISABLE_TLS=true
if [ -n "${DOMAIN}" ] && [ "${DISABLE_TLS}" != "true" ]; then
  LETSENCRYPT_PATH="/etc/letsencrypt/live/${DOMAIN}"
  if [ ! -d "${LETSENCRYPT_PATH}" ]; then
    apk add --no-cache certbot
    certbot certonly \
      --non-interactive \
      --agree-tos \
      --no-eff-email \
      --no-redirect \
      --email "admin@${DOMAIN}" \
      -d "${DOMAIN}" \
      --standalone
  fi
fi

# ------------------------------------------------------------
# Optional flags (node key, RLN credentials, lightpush)
# ------------------------------------------------------------
if [ -n "${NODEKEY}" ]; then
  NODEKEY="--nodekey=${NODEKEY}"
fi

if [ -n "${RLN_RELAY_CRED_PASSWORD}" ]; then
  RLN_RELAY_CRED_PASSWORD="--rln-relay-cred-password=${RLN_RELAY_CRED_PASSWORD}"
  LIGHTPUSH="--lightpush=true"
  RLN_RELAY_CRED_PATH="${RLN_RELAY_CRED_PATH:-/keystore/keystore.json}"
  echo "Using RLN credentials from ${RLN_RELAY_CRED_PATH}"
else
  LIGHTPUSH="--lightpush=false"
  RLN_RELAY_CRED_PATH=""
  RLN_RELAY_CRED_PASSWORD=""
fi

# ------------------------------------------------------------
# Store‑message retention policy (optional)
# ------------------------------------------------------------
if [ -n "${RETENTION_TIME}" ]; then
  STORE_RETENTION_POLICY="--store-message-retention-policy=time:${RETENTION_TIME}"
fi

# ------------------------------------------------------------
# Pick the binary that exists in the image
# ------------------------------------------------------------
if [ -x /usr/bin/wakunode2 ]; then
  BINARY="/usr/bin/wakunode2"
elif [ -x /usr/bin/wakunode ]; then
  BINARY="/usr/bin/wakunode"
else
  echo "❌ Neither /usr/bin/wakunode2 nor /usr/bin/wakunode is present in the image."
  exit 1
fi

# ------------------------------------------------------------
# TLS / WebSocket arguments (only when TLS is enabled)
# ------------------------------------------------------------
DNS_WSS_CMD=""
if [ -n "${DOMAIN}" ] && [ "${DISABLE_TLS}" != "true" ]; then
  WS_SUPPORT="--websocket-support=true"
  WSS_SUPPORT="--websocket-secure-support=true"
  WSS_KEY="--websocket-secure-key-path=${LETSENCRYPT_PATH}/privkey.pem"
  WSS_CERT="--websocket-secure-cert-path=${LETSENCRYPT_PATH}/fullchain.pem"
  DNS4_DOMAIN="--dns4-domain-name=${DOMAIN}"
  DNS_WSS_CMD="${WS_SUPPORT} ${WSS_SUPPORT} ${WSS_CERT} ${WSS_KEY} ${DNS4_DOMAIN}"
fi

# ------------------------------------------------------------
# EXECUTE THE NODE – ONLY FLAGS THAT EXIST IN v0.19.0
# ------------------------------------------------------------
exec "$BINARY" \
  --relay=true \
  --filter=true \
  ${LIGHTPUSH} \
  --keep-alive=true \
  --max-connections=150 \
  --discv5-discovery=true \
  --discv5-udp-port=9005 \
  --discv5-enr-auto-update=true \
  --log-level=INFO \
  --tcp-port=30304 \
  --metrics-server=true \
  --metrics-server-address=0.0.0.0 \
  --metrics-server-port=${METRICS_PORT:-8008} \   # <-- configurable via env var
  --rest=true \
  --rest-admin=true \                           # <-- enables admin API on 0.0.0.0:8646 (hard‑coded)
  --rest-address=0.0.0.0 \
  --rest-port=8645 \
  --nat=extip:"${MY_EXT_IP}" \
  --store=true \
  --store-message-db-url="postgres://${POSTGRES_USER}:${POSTGRES_PASSWORD}@postgres:5432/postgres" \
  --rln-relay-eth-client-address="${RLN_RELAY_ETH_CLIENT_ADDRESS}" \
  --rln-relay-tree-path="/etc/rln_tree" \
  ${RLN_RELAY_CRED_PATH} \
  ${RLN_RELAY_CRED_PASSWORD} \
  ${DNS_WSS_CMD} \
  ${NODEKEY} \
  ${STORE_RETENTION_POLICY} \
  ${EXTRA_ARGS}
