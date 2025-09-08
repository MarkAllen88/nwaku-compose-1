#!/usr/bin/env bash
set -euo pipefail
 
# -------------------------------------------------
#  1️⃣  Load environment variables from .env
# -------------------------------------------------
# Expected entries in .env (example):
#   RLN_RELAY_ETH_CLIENT_ADDRESS=https://linea-sepolia.infura.io/v3/<PROJECT_ID>
#   RLN_RELAY_ETH_PRIVATE_KEY=<your_private_key>
#   RLN_RELAY_ETH_CONTRACT_ADDRESS=0xB9cd878C90E49F797B4431fBF4fb333108CB90e6
#   TEST_STABLE_TOKEN_ADDRESS=0x5ddc2b6825f7eb721b80f5f3976e2bd3f0074817
#   RLN_RELAY_CHAIN_ID=59141
#   RLN_RELAY_CRED_PASSWORD=VeriDAO.io-v2!
#   RLN_RELAY_USER_MESSAGE_LIMIT=100
#
# Lines beginning with # are ignored.
# Values containing spaces must be quoted, e.g.:
#   SOME_VAR="value with spaces"

if [[ ! -f .env ]]; then
  echo "❌ .env file not found – please create it with the required variables."
  exit 1
fi

# Read the .env file line‑by‑line
while IFS= read -r line || [[ -n "$line" ]]; do
  # Trim leading/trailing whitespace
  line="$(echo "$line" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"

  # Skip empty lines or comments
  [[ -z "$line" ]] && continue
  [[ "$line" == \#* ]] && continue

  # Export the variable (allows quoted values)
  export "$line"
done < .env

# -------------------------------------------------
#  2️⃣  Helper to print nice sections
# -------------------------------------------------
section() {
  echo -e "\n🔹 $1"
}

# -------------------------------------------------
#  3️⃣  Show basic info
# -------------------------------------------------
section "Loaded environment"
echo "🪪 Sender address: $(cast wallet address "$RLN_RELAY_ETH_PRIVATE_KEY")"
BAL=$(cast balance "$(cast wallet address "$RLN_RELAY_ETH_PRIVATE_KEY")" \
        --rpc-url "$RLN_RELAY_ETH_CLIENT_ADDRESS")
echo "💰 Balance on Linea‑Sepolia: $BAL wei"

# -------------------------------------------------
#  4️⃣  Approve TestStableToken for the RLN contract
# -------------------------------------------------
# We approve a generous amount (100 STABLE, assuming 18 decimals)
APPROVE_AMOUNT=10000000000000000000   # 10 × 10¹⁸

section "Approving TestStableToken for RLN contract..."
cast send "$TEST_STABLE_TOKEN_ADDRESS" \
  "approve(address,uint256)" \
  "$RLN_RELAY_ETH_CONTRACT_ADDRESS" \
  "$APPROVE_AMOUNT" \
  --private-key "$RLN_RELAY_ETH_PRIVATE_KEY" \
  --rpc-url "$RLN_RELAY_ETH_CLIENT_ADDRESS"

echo "✅ Approval transaction submitted."

# -------------------------------------------------
#  5️⃣  Run Docker to generate the RLN keystore
# -------------------------------------------------
section "Running Docker to generate the RLN keystore"

DOCKER_IMAGE="wakuorg/nwaku:latest"

DOCKER_CMD=(
  docker run -v "$(pwd)/keystore":/keystore/:Z "$DOCKER_IMAGE" generateRlnKeystore
  --rln-relay-eth-client-address="$RLN_RELAY_ETH_CLIENT_ADDRESS"
  --rln-relay-eth-private-key="$RLN_RELAY_ETH_PRIVATE_KEY"
  --rln-relay-eth-contract-address="$RLN_RELAY_ETH_CONTRACT_ADDRESS"
  --rln-relay-chain-id="$RLN_RELAY_CHAIN_ID"
  --rln-relay-cred-path=/keystore/keystore.json
  --rln-relay-cred-password="$RLN_RELAY_CRED_PASSWORD"
  --rln-relay-dynamic=false 
  --execute
)

# Execute the Docker command; abort with a helpful message on failure
"${DOCKER_CMD[@]}" || {
  echo -e "\n❌ Docker container exited with an error."
  echo "Possible reasons:"
  echo "  • Insufficient allowance (now fixed by the larger approve amount)."
  echo "  • The RLN contract is paused or you are already registered."
  echo "  • Out‑of‑gas (unlikely with default limits)."
  exit 1
}

section "✅ Keystore generation completed!"
echo "🔐 Keystore file: $(pwd)/keystore/keystore.json"
echo "You can now use this file with your RLN‑enabled Waku node."

# -------------------------------------------------
#  End of script
# -------------------------------------------------
