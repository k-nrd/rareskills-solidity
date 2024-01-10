// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {IERC721} from "openzeppelin/token/ERC721/IERC721.sol";
import {IERC721Receiver} from "openzeppelin/token/ERC721/IERC721Receiver.sol";
import {ReentrancyGuard} from "openzeppelin/utils/ReentrancyGuard.sol";
import {Math} from "openzeppelin/utils/math/Math.sol";
import {ERC20Private} from "../lib/ERC20Private.sol";

/// @title NFT Vault
/// @notice This contract enables users to stake NFTs and earn ERC20 rewards.
/// @dev Implements a mechanism for staking ERC721 NFTs and distributing ERC20 rewards for staked NFTs.
contract NFTVault is IERC721Receiver, ReentrancyGuard {
    using Math for *;

    /// @notice Rewards allocated per asset per day.
    uint8 private constant REWARDS_PER_ASSET_PER_DAY = 10;

    /// @dev Accumulated rewards per asset, updated periodically.
    uint256 private _accRewardsPerAsset;

    /// @dev Timestamp of the last update to `_accRewardsPerAsset`.
    uint256 private _lastUpdateTimestamp;

    /// @dev Mapping to track allowed operators for accounts.
    mapping(address => mapping(address => bool)) private _allowedOperators;

    /// @dev Mapping to track which assets are staked by users.
    mapping(address => mapping(uint256 => bool)) private _usersAssets;

    /// @dev Mapping to track user balances and debts related to rewards.
    mapping(address => UserBalance) private _usersBalances;

    /// @notice The ERC721 NFT contract instance.
    IERC721 public assetContract;

    /// @notice The ERC20Private rewards contract instance.
    ERC20Private public rewardContract;

    /// @notice Emitted when a user deposits an NFT.
    event Deposit(address account, uint256 tokenId);

    /// @notice Emitted when a user withdraws an NFT.
    event Withdraw(address account, uint256 tokenId);

    /// @notice Emitted when a user harvests rewards.
    event Harvest(address account, uint256 rewards);

    /// @notice Emitted when rewards are updated.
    event Update(uint256 timestamp, uint256 accRewardsPerAsset);

    /// @dev Struct to store user's reward balance and staked asset count.
    struct UserBalance {
        uint256 rewardDebt;
        uint256 assetAmount;
    }

    /// @notice Initializes the NFT Vault with a specified reward and asset contract.
    /// @dev This contract needs to own the `rewardContract_`.
    /// @param rewardContract_ The ERC20Private contract for reward tokens.
    /// @param assetContract_ The ERC721 contract for NFT assets.
    constructor(ERC20Private rewardContract_, IERC721 assetContract_) {
        assetContract = assetContract_;
        rewardContract = rewardContract_;
        _accRewardsPerAsset = 0;
        _lastUpdateTimestamp = block.timestamp;
    }

    /// @dev Modifier to update the accumulated rewards before executing a function.
    modifier updates() {
        _update();
        _;
    }

    /// @notice Returns the asset contract address.
    function asset() public view returns (address) {
        return address(assetContract);
    }

    /// @notice Returns the total number of assets staked in the vault.
    function totalAssets() public view returns (uint256) {
        return assetContract.balanceOf(address(this));
    }

    /// @notice Returns the total number of rewards issued by the vault.
    function totalRewards() public view returns (uint256) {
        return rewardContract.totalSupply();
    }

    /// @notice Approves an operator to manage the caller's assets.
    /// @param operator The address to approve as an operator.
    function approve(address operator) external {
        require(msg.sender != operator, "Account is always an operator for itself.");
        _allowedOperators[msg.sender][operator] = true;
    }

    /// @notice Checks if an address is an operator for another account.
    /// @param account The account to check the operator status for.
    /// @return True if the address is an operator for the account.
    function isOperator(address account) public view returns (bool) {
        return account == msg.sender || _allowedOperators[account][msg.sender];
    }

    /// @notice Deposits an NFT into the vault for staking.
    /// @param account The account that owns the NFT.
    /// @param tokenId The tokenId of the NFT to be staked.
    function deposit(address account, uint256 tokenId) external nonReentrant {
        require(isOperator(account), "Caller is not an operator for account.");

        _deposit(account, tokenId);

        emit Deposit(account, tokenId);
    }

    /// @notice Withdraws an NFT from the vault.
    /// @param account The account that owns the NFT.
    /// @param tokenId The tokenId of the NFT to be withdrawn.
    function withdraw(address account, uint256 tokenId) external nonReentrant {
        require(isOperator(account), "Caller is not an operator for account.");
        require(_usersAssets[account][tokenId], "Account is not the asset owner.");

        _withdraw(account, tokenId);

        emit Withdraw(account, tokenId);
    }

    /// @notice Allows a user to harvest their accrued rewards.
    /// @param account The account to harvest rewards for.
    function harvest(address account) public {
        require(isOperator(account), "Caller is not an operator for account.");
        _harvest(account);
    }

    /// @notice Provides an estimate of the rewards that can be harvested for a given account.
    /// @param account The account to estimate rewards for.
    /// @return The amount of rewards that can be harvested.
    function previewHarvest(address account) public view returns (uint256) {
        return _calculateRewards(account);
    }

    /// @dev Required implementation of the ERC721Receiver interface.
    function onERC721Received(address, address, uint256, bytes calldata) external pure returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }

    /// @dev Deposits an NFT into the vault, updating the user's balance and reward debt.
    /// @param account The address of the account depositing the NFT.
    /// @param tokenId The ID of the NFT to deposit.
    function _deposit(address account, uint256 tokenId) internal updates {
        _usersAssets[account][tokenId] = true;
        _usersBalances[account].rewardDebt += _accRewardsPerAsset;
        _usersBalances[account].assetAmount += 1;
        assetContract.safeTransferFrom(account, address(this), tokenId);
    }

    /// @dev Withdraws an NFT from the vault, updating the user's balance and harvesting rewards.
    /// @param account The address of the account withdrawing the NFT.
    /// @param tokenId The ID of the NFT to withdraw.
    function _withdraw(address account, uint256 tokenId) internal {
        _harvest(account);
        _usersAssets[account][tokenId] = false;
        _usersBalances[account].assetAmount -= 1;
        assetContract.safeTransferFrom(address(this), account, tokenId);
    }

    /// @dev Calculates and mints rewards for the specified account.
    /// @param account The address of the account to harvest rewards for.
    function _harvest(address account) internal updates {
        uint256 userRewards = _calculateRewards(account);
        require(userRewards > 0, "User can't harvest yet.");
        _usersBalances[account].rewardDebt += userRewards;
        rewardContract.mint(account, userRewards * (10 ** rewardContract.decimals()));
        emit Harvest(account, userRewards);
    }

    /// @dev Calculates the rewards owed to a specific account.
    /// @param account The address of the account to calculate rewards for.
    /// @return The amount of rewards owed to the account.
    function _calculateRewards(address account) internal view returns (uint256) {
        UserBalance memory userBalance = _usersBalances[account];
        return (_accRewardsPerAsset * userBalance.assetAmount) - userBalance.rewardDebt;
    }

    /// @dev Internal function to update the accumulated rewards per asset.
    /// @return True if the update was performed, false otherwise.
    /// @notice This function updates the accumulated rewards per asset based on the elapsed time.
    function _update() internal returns (bool) {
        // Do not update unless 1 or more days have passed
        uint256 currentTime = block.timestamp;
        uint256 timeElapsed = currentTime - _lastUpdateTimestamp;
        if (timeElapsed < 1 days) {
            return false;
        }

        // Calculate how much an asset would have accrued in the period
        _accRewardsPerAsset += (timeElapsed * REWARDS_PER_ASSET_PER_DAY) / 1 days;

        // Set the new last update timestamp
        _lastUpdateTimestamp = currentTime;

        emit Update(_lastUpdateTimestamp, _accRewardsPerAsset);
        return true;
    }
}
