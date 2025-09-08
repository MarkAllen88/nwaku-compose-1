/**
 * create_keystore.js – Generate an RLN keystore for nwaku
 *
 * Prerequisites:
 *   • npm i ethers rlnjs @waku/zerokit-rln-wasm
 *
 * What this script does:
 *   1️⃣ Load your Ethereum private key.
 *   2️⃣ Initialise RLN with the correct file‑paths.
 *   3️⃣ Derive a deterministic RLN identity from a signed seed.
 *   4️⃣ Assemble the keystore JSON in the exact shape nwaku expects.
 *   5️⃣ Write the JSON to ./keystore/keystore.json.
 */

const fs   = require('fs');
const path = require('path');
const { ethers } = require('ethers');
const { RLN }    = require('rlnjs');

// ------------------------------------------------------------------
// 👉 1️⃣  YOUR ETHEREUM PRIVATE KEY
// ------------------------------------------------------------------
const ethPrivateKey = '0xfbb4cdb63cc7ad693beab89467d57d9c83b4080142ece3ae75fb17a018eea877';
// ⚠️ Never commit real keys. In production use env vars.

// ------------------------------------------------------------------
// 👉 2️⃣  RLN CONFIGURATION – point at the binaries shipped by @waku/zerokit-rln-wasm
// ------------------------------------------------------------------
const wasmFilePath   = path.join(
  __dirname,
  'node_modules',
  '@waku',
  'zerokit-rln-wasm',
  'dist',
  'rln.wasm'
);
const finalZkeyPath = path.join(
  __dirname,
  'node_modules',
  '@waku',
  'zerokit-rln-wasm',
  'dist',
  'rln_final.zkey'
);

// Defensive checks – fail fast if something is missing.
if (!fs.existsSync(wasmFilePath)) {
  throw new Error(`Missing WASM file at ${wasmFilePath}`);
}
if (!fs.existsSync(finalZkeyPath)) {
  throw new Error(`Missing ZKEY file at ${finalZkeyPath}`);
}

// Initialise RLN – the constructor expects exactly these property names.
const rln = new RLN({ wasmFilePath, finalZkeyPath });

// ------------------------------------------------------------------
// 👉 3️⃣  MAIN LOGIC
// ------------------------------------------------------------------
async function main() {
  console.log('🚀 Starting RLN keystore generation…');

  // 3a️⃣  Create an ethers wallet from the private key
  const wallet = new ethers.Wallet(ethPrivateKey);
  const ethAddress = wallet.address;
  console.log(`🪪 Loaded wallet for address: ${ethAddress}`);

  // 3b️⃣  Derive a deterministic seed by signing a static message
  const signature = await wallet.signMessage('waku-rln-id-seed');

  // 3c️⃣  Generate RLN credentials from that seed
  const { identitySecret, identityCommitment } = rln.generateSeededRLNKeys(signature);
  const identityCommitmentHex = RLN.toHex(identityCommitment);
  console.log(`🔑 RLN Identity Commitment: ${identityCommitmentHex}`);

  // 3d️⃣  Build the keystore object exactly as nwaku expects
  const keystore = {
    rlnIdentifier: 'waku-rln-v1',
    idSecret: Buffer.from(identitySecret).toString('hex'),
    idCommitment: identityCommitmentHex.replace(/^0x/, ''),
    ethAddress: ethAddress.replace(/^0x/, ''),
    appId: 'waku-rln-relay',
  };

  // 3e️⃣  Ensure the output folder exists
  const keystoreDir = path.join(__dirname, 'keystore');
  if (!fs.existsSync(keystoreDir)) {
    fs.mkdirSync(keystoreDir);
  }

  // 3f️⃣  Write the JSON file (pretty‑printed)
  const keystorePath = path.join(keystoreDir, 'keystore.json');
  fs.writeFileSync(keystorePath, JSON.stringify(keystore, null, 2));
  console.log('\n✅ Keystore generation completed!');
  console.log(`📁 Keystore written to: ${keystorePath}`);
}

// ------------------------------------------------------------------
// 👉 Run the script & handle errors gracefully
// ------------------------------------------------------------------
main().catch(err => {
  console.error('❌ An error occurred during keystore generation:', err);
  process.exit(1);
});
