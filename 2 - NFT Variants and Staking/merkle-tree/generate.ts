import { keccak256, encodePacked, Address } from "viem"
import { StandardMerkleTree } from "@openzeppelin/merkle-tree"
import * as fs from "fs"

type WhitelistEntry = [Address, string]

// Read the whitelist entries from the JSON file
const whitelist: WhitelistEntry[] = [
  ["0x0000000000000000000000000000000000000001", "0"],
  ["0x0000000000000000000000000000000000000002", "1"],
]

// Create the Merkle tree
const merkleTree = StandardMerkleTree.of(whitelist, ["address", "uint256"])

// Get the Merkle root
const merkleRoot = merkleTree.root

// Function to generate and write Merkle proof for an address to a JSON file
const generateAndWriteMerkleProof = (): void => {
  for (const [i, v] of merkleTree.entries()) {
    const proof = merkleTree.getProof(i)
    fs.writeFileSync(`proofs/proof_${i}.json`, JSON.stringify(proof, null, 2))
    console.log(`Proof ${i} written to proofs/proof_${i}.json`)
  }
}

// Ensure proofs directory exists
if (!fs.existsSync("proofs")) {
  fs.mkdirSync("proofs")
}

console.group("Generating Merkle Tree and Proofs")
console.log("Merkle Root: ", merkleRoot)

// Generate and write proofs for all entries
generateAndWriteMerkleProof()

console.groupEnd()
