#!/usr/bin/env bash
set -euo pipefail

# --------------------------------------------------------------
# 0️⃣  Define where we keep the intermediate artefacts
# --------------------------------------------------------------
BUILD_DIR=$(realpath ../build)   # change if you prefer another location
mkdir -p "$BUILD_DIR"

# --------------------------------------------------------------
# 1️⃣  Compile the RLN circuit (produces rln.r1cs, rln.sym, rln_js/)
# --------------------------------------------------------------
# Ensure circom is on your PATH; if you installed via npm:
#   npm install -g circom
circom circuits/rln.circom \
    -l node_modules \          # include local libraries
    --r1cs --sym --wasm -o .   # output files in the current dir

# Move the compiled artefacts to the build folder (optional but tidy)
mv rln.r1cs rln.sym rln_js "$BUILD_DIR/"

# --------------------------------------------------------------
# 2️⃣  Generate a fresh Powers‑of‑Tau (you already did steps 1‑3,
#     but we repeat here for completeness)
# --------------------------------------------------------------
cd "$BUILD_DIR"

# 2a️⃣  Start a new ceremony (2^14 points → enough for RLN)
snarkjs powersoftau new bn128 14 pot14_0000.ptau -v

# 2b️⃣  Add your entropy contribution
snarkjs powersoftau contribute pot14_0000.ptau pot14_0001.ptau \
    --name="Marko contribution" -v

# 2c️⃣  **Prepare phase‑2** (the step you were missing)
snarkjs powersoftau prepare phase2 pot14_0001.ptau pot14_0002.ptau -v
# (short alias: snarkjs pt2 pot14_0001.ptau pot14_0002.ptau -v)

# --------------------------------------------------------------
# 3️⃣  Groth‑16 trusted‑setup using the R1CS and the phase‑2 PTau
# --------------------------------------------------------------
snarkjs groth16 setup "$BUILD_DIR/rln.r1cs" pot14_0002.ptau rln_0000.zkey -v

# --------------------------------------------------------------
# 4️⃣  Add a ZKey contribution (you can repeat this step many times)
# --------------------------------------------------------------
snarkjs zkey contribute rln_0000.zkey rln_0001.zkey \
    --name="Marko contribution #2" -v

# --------------------------------------------------------------
# 5️⃣  (Optional) Beacon phase – deterministic randomness
# --------------------------------------------------------------
snarkjs zkey beacon rln_0001.zkey rln_final.zkey \
    0102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f \
    --name="Beacon" -v

# --------------------------------------------------------------
# 6️⃣  Verify the final ZKey (highly recommended)
# --------------------------------------------------------------
snarkjs zkey verify "$BUILD_DIR/rln.r1cs" pot14_0002.ptau rln_final.zkey

# --------------------------------------------------------------
# 7️⃣  Export the verification key (what a verifier needs)
# --------------------------------------------------------------
snarkjs zkey export verificationkey rln_final.zkey verification_key.json

echo "✅ All artefacts are in $BUILD_DIR"
