#!/usr/bin/env bash
# --------------------------------------------------------------
# build_rln_zkey.sh – Trusted‑setup for the RLN circuit (macOS)
# Updated to include the required “prepare phase2” step.
# --------------------------------------------------------------

set -euo pipefail   # abort on error, treat unset vars as errors, fail pipelines

# ------------------------------------------------------------------
# 1️⃣ Clone the RLN circuit repository
# ------------------------------------------------------------------
REPO_URL="https://github.com/rate-limiting-nullifier/circom-rln.git"
REPO_DIR="circom-rln"

rm -rf "${REPO_DIR}"
git clone "${REPO_URL}"
cd "${REPO_DIR}"

# ------------------------------------------------------------------
# 2️⃣ Install JS dependencies (node_modules) – needed for circuit includes
# ------------------------------------------------------------------
echo "📦 Installing JS dependencies (node_modules)…"
npm ci   # deterministic install; falls back to `npm install` if no lockfile

# ------------------------------------------------------------------
# 3️⃣ Install snarkjs globally (so you can reuse it later)
# ------------------------------------------------------------------
echo "🔧 Installing snarkjs globally…"
npm i -g snarkjs || {
    echo "⚠️  Global install failed – will rely on npx."
}

# ------------------------------------------------------------------
# 4️⃣ Locate a usable circom binary
# ------------------------------------------------------------------
if command -v circom >/dev/null 2>&1; then
    echo "ℹ️  Using existing 'circom' from $(command -v circom)"
    CIRCOM_BIN="$(command -v circom)"
else
    CIRCOM_URL="https://github.com/iden3/circom/releases/download/v2.2.0/circom-macos-amd64"
    CIRCOM_BIN="${PWD}/circom"
    echo "⬇️  Downloading circom for macOS (amd64)…"
    curl -L "${CIRCOM_URL}" -o "${CIRCOM_BIN}"
    chmod +x "${CIRCOM_BIN}"
fi

# ------------------------------------------------------------------
# 5️⃣ Compile the RLN circuit (new CLI syntax)
# ------------------------------------------------------------------
CIRCUIT_PATH="circuits/rln.circom"
echo "🔧 Compiling ${CIRCUIT_PATH} …"
"${CIRCOM_BIN}" "${CIRCUIT_PATH}" \
    -l node_modules \
    --r1cs \
    --wasm \
    -o .

# ------------------------------------------------------------------
# Helper: run snarkjs via npx if the binary isn’t on PATH
# ------------------------------------------------------------------
run_snarkjs() {
    if command -v snarkjs >/dev/null 2>&1; then
        snarkjs "$@"
    else
        npx snarkjs "$@"
    fi
}

# ------------------------------------------------------------------
# 6️⃣ Power‑of‑Tau ceremony – 14 phases (fits RLN size)
# ------------------------------------------------------------------
POWER_TAU_EXP=14   # 2^14 = 16384 → max ≈ 32768 constraints (enough for RLN)

echo "🔐 Running Power‑of‑Tau ceremony (${POWER_TAU_EXP} phases)…"
run_snarkjs powersoftau new bn128 "${POWER_TAU_EXP}" pot${POWER_TAU_EXP}_0000.ptau -v

echo "🔐 Contributing entropy to the ceremony…"
run_snarkjs powersoftau contribute pot${POWER_TAU_EXP}_0000.ptau pot${POWER_TAU_EXP}_0001.ptau \
    --name="Setup contribution" -v

# ------------------------------------------------------------------
# 7️⃣ **Prepare phase‑2** – this step was missing before
# ------------------------------------------------------------------
echo "🔧 Preparing phase‑2 (this creates the file used by Groth16)…"
run_snarkjs powersoftau prepare phase2 pot${POWER_TAU_EXP}_0001.ptau pot${POWER_TAU_EXP}_0001.ptau -v

# ------------------------------------------------------------------
# 8️⃣ Groth16 setup (uses the prepared phase‑2 PTau file)
# ------------------------------------------------------------------
echo "🛠️  Groth16 setup…"
run_snarkjs groth16 setup rln.r1cs pot${POWER_TAU_EXP}_0001.ptau rln_0000.zkey

# ------------------------------------------------------------------
# 9️⃣ ZKey contribution
# ------------------------------------------------------------------
echo "🔑 First ZKey contribution…"
run_snarkjs zkey contribute rln_0000.zkey rln_0001.zkey \
    --name="Contributor 1" -v

# ------------------------------------------------------------------
# 🔟 Beacon phase (deterministic randomness)
# ------------------------------------------------------------------
echo "🚨 Beacon phase…"
run_snarkjs zkey beacon rln_0001.zkey rln_final.zkey \
    0102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f \
    --name="Beacon" -v

# ------------------------------------------------------------------
# 📏 Verify the final ZKey (optional but recommended)
# ------------------------------------------------------------------
echo "🔎 Verifying final ZKey…"
run_snarkjs zkey verify rln.r1cs pot${POWER_TAU_EXP}_0001.ptau rln_final.zkey || {
    echo "⚠️  Verification failed – the ZKey may be corrupted."
    exit 1
}

# ------------------------------------------------------------------
# 🎉 All done
# ------------------------------------------------------------------
echo "✅ rln_final.zkey is ready at $(pwd)/rln_final.zkey"
