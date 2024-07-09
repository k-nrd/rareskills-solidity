## What pieces of information go in to an EIP 712 delimiter, and what could go wrong if those were omitted?

`EIP712Domain` contains these pieces of data:

- `string name` (name of the verifying contract)
- `string version` (current version of the verifying contract)
- `uint256 chainId` (ID of the chain the verifying contract is running in)
- `address verifyingContract` (address of the verifying contract)
- `bytes32 salt` (as a last resort, can be used to eliminate ambiguity)

If `name` was omitted, it would make it hard to present to the user with actionable information, but it would not be necessarily exploitable.
If `version` was omitted, a message could be made expecting the verifying contract to be in a different version than it currently is.
If `chainId` was omitted, a message could be verified in a different chain altogether, and this could be exploited.
If `verifyingContract` was omitted, then a different verifying contract could be used altogether, subverting user expectations and this could be exploited.
If `salt` was omitted, this wouldn't be necessarily exploitable, but if somehow all the other fields match another contract, it could be used to eliminate ambiguity.
