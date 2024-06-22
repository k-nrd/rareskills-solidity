import {
  useAccount,
  useConnect,
  useDisconnect,
  useReadContract,
  useSignTypedData,
} from "wagmi";
import { damnValuableTokenPermitAbi } from "./generated.ts";
import { Address, parseUnits, zeroAddress } from "viem";
import { sepolia } from "viem/chains";
import { useEffect } from "react";

const contractAddress = "0x2e2774e6A06Fd7355308924D296a47983aC16d09" as Address;

function App() {
  const account = useAccount();

  const { connectors, connect, status, error } = useConnect();
  const { disconnect } = useDisconnect();

  const { signTypedData } = useSignTypedData();

  const { data: nonce } = useReadContract({
    abi: damnValuableTokenPermitAbi,
    address: contractAddress,
    functionName: "nonces",
    args: account.address != null ? [account.address] : undefined,
  });

  const spender = zeroAddress;
  const value = parseUnits("1", 18);
  const deadline = Math.floor(Date.now() / 1000) + 3600; // 1 hour from now

  const types = {
    Permit: [
      { name: "owner", type: "address" },
      { name: "spender", type: "address" },
      { name: "value", type: "uint256" },
      { name: "nonce", type: "uint256" },
      { name: "deadline", type: "uint256" },
    ],
  } as const;

  const domain = {
    name: "DamnValuableTokenPermit",
    version: "1",
    chainId: sepolia.id,
    verifyingContract: contractAddress,
  };

  const message = {
    owner: account.address as Address,
    spender,
    value,
    deadline: BigInt(deadline),
    nonce: nonce as bigint,
  };

  useEffect(() => {
    console.group("typed message");
    console.log("domain: ", domain);
    console.log("message: ", message);
    console.groupEnd();
  }, [account.address, message, nonce]);

  return (
    <>
      <div>
        <h2>Account</h2>

        <div>
          status: {account.status}
          <br />
          addresses: {JSON.stringify(account.addresses)}
          <br />
          chainId: {account.chainId}
        </div>

        {account.status === "connected" && (
          <>
            <button type="button" onClick={() => disconnect()}>
              Disconnect
            </button>
            <button
              type="button"
              onClick={() =>
                signTypedData({ primaryType: "Permit", types, domain, message })
              }
            >
              Sign typed data
            </button>
          </>
        )}
      </div>

      <div>
        <h2>Connect</h2>
        {connectors.map((connector) => (
          <button
            key={connector.uid}
            onClick={() => connect({ connector })}
            type="button"
          >
            {connector.name}
          </button>
        ))}
        <div>{status}</div>
        <div>{error?.message}</div>
      </div>
    </>
  );
}

export default App;
