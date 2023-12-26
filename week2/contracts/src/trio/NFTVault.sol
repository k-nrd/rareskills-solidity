// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {IERC721} from "openzeppelin/token/ERC721/IERC721.sol";
import {IERC721Receiver} from "openzeppelin/token/ERC721/IERC721Receiver.sol";
import {Math} from "openzeppelin/utils/math/Math.sol";
import {ERC20Private} from "../lib/ERC20Private.sol";

contract NFTVault is IERC721Receiver {
    using Math for *;

    uint8 private immutable REWARDS_PER_ASSET_PER_DAY = 10;

    uint256 private _accRewardsPerAsset;
    uint256 private _lastUpdateTimestamp;

    mapping(address => mapping(address => bool)) private _allowedOperators;
    mapping(address => mapping(uint256 => bool)) private _usersAssets;
    mapping(address => UserBalance) private _usersBalances;

    IERC721 public assetContract;
    ERC20Private public rewardContract;

    event Deposit(address account, uint256 tokenId);
    event Withdraw(address account, uint256 tokenId);
    event Harvest(address account, uint256 rewards);
    event Update(uint256 timestamp, uint256 accRewardsPerAsset);

    struct UserBalance {
        uint256 rewardDebt;
        uint256 assetAmount;
    }

    constructor(ERC20Private rewardContract_, IERC721 assetContract_) {
        assetContract = assetContract_;
        rewardContract = rewardContract_;
        _accRewardsPerAsset = 0;
        _lastUpdateTimestamp = block.timestamp;
    }

    modifier updates() {
        _update();
        _;
    }

    function asset() public view returns (address) {
        return address(assetContract);
    }

    function totalAssets() public view returns (uint256) {
        return assetContract.balanceOf(address(this));
    }

    function totalRewards() public view returns (uint256) {
        return rewardContract.totalSupply();
    }

    function approve(address operator) external {
        require(msg.sender != operator, "Account is always an operator for itself.");
        _allowedOperators[msg.sender][operator] = true;
    }

    function isOperator(address account) public view returns (bool) {
        return account == msg.sender || _allowedOperators[account][msg.sender];
    }

    function deposit(address account, uint256 tokenId) external {
        require(isOperator(account), "Caller is not an operator for account.");

        _deposit(account, tokenId);

        emit Deposit(account, tokenId);
    }

    function withdraw(address account, uint256 tokenId) external {
        require(isOperator(account), "Caller is not an operator for account.");
        require(_usersAssets[account][tokenId], "Account is not the asset owner.");

        _withdraw(account, tokenId);

        emit Withdraw(account, tokenId);
    }

    function harvest(address account) public {
        require(isOperator(account), "Caller is not an operator for account.");
        _harvest(account);
    }

    function previewHarvest(address account) public view returns (uint256) {
        return _calculateRewards(account);
    }

    function onERC721Received(address, address, uint256, bytes calldata) external pure returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }

    function _deposit(address account, uint256 tokenId) internal updates {
        assetContract.safeTransferFrom(account, address(this), tokenId);
        _usersAssets[account][tokenId] = true;
        _usersBalances[account].rewardDebt += _accRewardsPerAsset;
        _usersBalances[account].assetAmount += 1;
    }

    function _withdraw(address account, uint256 tokenId) internal {
        _harvest(account);
        assetContract.safeTransferFrom(address(this), account, tokenId);
        _usersAssets[account][tokenId] = false;
        _usersBalances[account].assetAmount -= 1;
    }

    function _harvest(address account) internal updates {
        uint256 userRewards = _calculateRewards(account);
        require(userRewards > 0, "User can't harvest yet.");

        rewardContract.mint(account, userRewards);
        _usersBalances[account].rewardDebt += userRewards;

        emit Harvest(account, userRewards);
    }

    function _calculateRewards(address account) internal view returns (uint256) {
        UserBalance memory userBalance = _usersBalances[account];
        return (_accRewardsPerAsset * userBalance.assetAmount) - userBalance.rewardDebt;
    }

    function _update() internal returns (bool) {
        uint256 daysSinceUpdate = (block.timestamp - _lastUpdateTimestamp) / 60 * 60 * 24;
        if (daysSinceUpdate < 1) {
            return false;
        }

        _accRewardsPerAsset += daysSinceUpdate * REWARDS_PER_ASSET_PER_DAY;
        _lastUpdateTimestamp = block.timestamp;

        emit Update(_lastUpdateTimestamp, _accRewardsPerAsset);

        return true;
    }
}
