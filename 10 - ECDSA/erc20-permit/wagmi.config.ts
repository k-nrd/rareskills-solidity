import { defineConfig } from "@wagmi/cli";
import abi from "./src/DamnValuableTokenAbi.json";
import { Abi } from "viem";

export default defineConfig({
  out: "./src/generated.ts",
  contracts: [
    {
      name: "DamnValuableTokenPermit",
      abi: abi as Abi,
    },
  ],
});
