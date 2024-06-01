# Solidity Proxies Q&A

## Question 1: The OZ upgrade tool for hardhat defends against 6 kinds of mistakes. What are they and why do they matter?

### 1. Validates the implementation

`deployProxy` makes sure the implementation is _upgrade-safe_. This means it checks that the implementation:

- Does not have a constructor
- Does not use `selfdestruct`
- Does not use `delegatecall`

The constructor check is sensible - since the implementation won't have access to the storage layer (the proxy),
any initialization logic must live in a separate `initialize` function (or similar function).
`selfdestruct` is blocked for a simple reason: if the implementation can be destroyed, then all proxies will point to an address without code,
breaking the whole system.
Since a `delegatecall` could be used to call a malicious contract with `selfdestruct`, it presents the same issues as `selfdestruct` itself.

### 2. Storage layout incompatibilities

`upgradeProxy` checks that the new implementation is _compatible_ with the previous one, meaning the
storage layout is either the same or an extension.

### 3. Initializer re-runs

The `initializer` modifier prevents initializer function from running more than once. An initializer function that runs more than once could be used for malicious purposes.

### 4. Uninitialized contracts

`deployProxy` also initializes the contract after deploying it. An uninitialized implementation contract can be taken over by an attacker who can call the initialize function, setting themselves as the owner or performing other malicious actions.

### 5. Storage collisions

When adding new variables to the storage layout of base contracts, one might generate storage collisions. Through ERC-7201 and OZ plugins, one can avoid generating those.

### 6. Redeploying implementation contracts

`deployProxy`, before deploying your new implementation, first checks if there's already an implementation contract with the same bytecode, to avoid duplicate deployments.

## Question 2: What is a beacon proxy used for?

In the context of multiple proxies, a beacon contract is a singleton reference to the current implementation.
If the implementation changes, the beacon is updated, and all proxies have access to the new code.

## Question 3: Why does the OpenZeppelin upgradeable tool insert something like `uint256[50] private __gap;` inside the contracts?

Gaps like `uint256[50] private __gap` are inserted to allow for future upgrades without changing the storage layout of the contract.
In this case, we're reserving 50 32-byte slots.

## Question 4: What is the difference between initializing the proxy and initializing the implementation? Do you need to do both? When do they need to be done?

Initializing the proxy involves setting up the initial state variables of the proxy contract, which will use the implementation's logic. It's usually done through the proxy's constructor, and it might be used to set up its first implementation address and owner.

Initializing the implementation is done through an initializer function, since the constructor wouldn't run in the context of the proxy's storage. This is useful because implementations might depend on a storage variable which needs to be initialized to some base value - a delegatecall to the implementation's initializer function would set that base value in the proxy's storage.

## Question 5: What is the use for the re-initializer? Provide a minimal example of proper use in Solidity

`reinitializer`s are used when a new implementation adds new storage variables that also need to be initialized to starting values. Since an `initializer` function is already present and was presumably already invoked, OZ provides a `reinitializer` modifier that allows you to create new initializing functions that run only once per version. Example below:

```solidity
contract MyToken is ERC20Upgradeable {
    function initialize() initializer public {
        __ERC20_init("MyToken", "MTK");
    }
}

contract MyTokenV2 is MyToken, ERC20PermitUpgradeable {
    function initializeV2() reinitializer(2) public {
        __ERC20Permit_init("MyToken");
    }
}
```
