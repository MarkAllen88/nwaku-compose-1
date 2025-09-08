#!/usr/bin/env node
// This script converts a 12‑word (or 24‑word) seed phrase into a raw 64‑hex private key.
// Usage: ./mnemonic-to-pk.js "<12‑word‑mnemonic>" [index]
//   <mnemonic> – your exact seed phrase, quoted.
//   [index]    – optional account index (default 0). Change to 1,2,… if the address you need isn’t the first one.
const { ethers } = require('ethers');

if (process.argv.length < 3) {
  console.error('Usage: ./mnemonic-to-pk.js "<12‑word‑mnemonic>" [index]');
  process.exit(1);
}
const mnemonic = process.argv[2].trim();
const index = parseInt(process.argv[3] ?? '0', 10);   // default to first account

// Derive the HD node for Ethereum (BIP‑44)
// Path: m/44\'/60\'/0\'/0/<index>
const hdNode = ethers.utils.HDNode.fromMnemonic(mnemonic);
const child = hdNode.derivePath(`m/44'/60'/0'/0/${index}`);

// Output the private key *without* the leading 0x
console.log(child.privateKey.slice(2));
