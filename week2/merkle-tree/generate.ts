import { MerkleTree } from "merkletreejs"
import { keccak256, encodePacked, Address } from "viem"
import * as fs from "fs"

// Read the whitelist entries from the JSON file
const whitelist: Address[] = JSON.parse(
  fs.readFileSync("addresses.json", "utf-8"),
)

const toLeaf = (addr: Address, index: number): string =>
  keccak256(encodePacked(["uint256", "address"], [BigInt(index), addr]))

// Generate leaf nodes for the Merkle tree
const leafNodes = whitelist.map(toLeaf)

// Create the Merkle tree
const merkleTree = new MerkleTree(leafNodes, keccak256, { sortPairs: true })

// Get the Merkle root
const merkleRoot = merkleTree.getHexRoot()

// Function to generate and write Merkle proof for an address to a JSON file
const generateAndWriteMerkleProof = (addr: Address, index: number): void => {
  const leaf = toLeaf(addr, index)
  const proof = merkleTree.getHexProof(leaf)
  fs.writeFileSync(`proofs/proof_${index}.json`, JSON.stringify(proof, null, 2))
  console.log(`Proof ${index} written to proofs/proof_${index}.json`)
}

// Ensure proofs directory exists
if (!fs.existsSync("proofs")) {
  fs.mkdirSync("proofs")
}

console.group("Generating Merkle Tree and Proofs")
console.log("Merkle Root: ", merkleRoot)

// Generate and write proofs for all entries
whitelist.forEach(generateAndWriteMerkleProof)

console.groupEnd()
