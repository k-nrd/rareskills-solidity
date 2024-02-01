// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {ERC20} from "solady/tokens/ERC20.sol";
import {ReentrancyGuard} from "solady/utils/ReentrancyGuard.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {FixedPointMathLib} from "solady/utils/FixedPointMathLib.sol";
import {IPairBorrower} from "./interfaces/IPairBorrower.sol";
import {IERC20} from "./interfaces/IERC20.sol";

contract Pair is ERC20, ReentrancyGuard {
    using SafeTransferLib for *;
    using FixedPointMathLib for uint256;

    // Use a single storage slot
    uint224 private constant Q112 = 2 ** 112;
    uint32 private constant MINIMUM_SHARES = 10 ** 3;

    string private _name;
    string private _symbol;

    // Use a single storage slot
    uint112 private _reserves0;
    uint112 private _reserves1;
    uint32 private _lastUpdatedTimestamp;

    uint256 public accumulatedPrice0;
    uint256 public accumulatedPrice1;

    address public immutable token0;
    address public immutable token1;

    // Use a single storage slot
    uint128 public immutable swapFeeBasisPoints;
    uint128 public immutable loanFeeBasisPoints;

    event Update(uint112 reserves0, uint112 reserves1);
    event Deposit(
        address holder,
        address operator,
        uint256 assets0,
        uint256 assets1,
        uint256 sharesMinted
    );
    event Withdraw(
        address holder,
        address operator,
        uint256 assets0,
        uint256 assets1,
        uint256 sharesBurned
    );
    event Swap(
        address swapper,
        address operator,
        uint256 inputAssets,
        uint256 outputAssets
    );
    event Loan(
        address borrower,
        address operator,
        uint256 assets0Borrowed,
        uint256 assets1Borrowed,
        uint256 assets0Returned,
        uint256 assets1Returned
    );

    constructor(
        string memory name_,
        string memory symbol_,
        address token0_,
        address token1_,
        uint128 swapFeeBasisPoints_,
        uint128 loanFeeBasisPoints_
    ) {
        _name = name_;
        _symbol = symbol_;

        token0 = token0_;
        token1 = token1_;
        swapFeeBasisPoints = swapFeeBasisPoints_;
        loanFeeBasisPoints = loanFeeBasisPoints_;
    }

    function deposit(
        address from,
        uint256 assets0,
        uint256 assets1,
        uint256 minSharesExpected
    ) external nonReentrant {
        // Gas savings
        address pair = address(this);
        uint256 totalShares = totalSupply();
        uint256 shares;
        // Calculate how many shares they should get
        if (totalShares == 0) {
            require(assets0 > 0 && assets1 > 0, "PAIR: INVALID_FIRST_MINT");
            // We haven't minted any shares yet
            shares = (assets0 * assets1).sqrt() - MINIMUM_SHARES;
            // Mint minimum liquidity, this mitigates donation attacks
            _mint(address(0), MINIMUM_SHARES);
        } else {
            // Always round in favor of liquidity providers
            shares = FixedPointMathLib.min(
                assets0.fullMulDiv(totalShares, _reserves0),
                assets1.fullMulDiv(totalShares, _reserves1)
            );
        }
        require(shares >= minSharesExpected, "PAIR: DEPOSIT_SLIPPAGE_EXCEEDED");

        _mint(from, shares);
        _update();

        // Don't execute 2 transfers if we only need 1
        if (assets0 > 0) {
            SafeTransferLib.safeTransferFrom(token0, from, pair, assets0);
        }
        if (assets1 > 0) {
            SafeTransferLib.safeTransferFrom(token1, from, pair, assets1);
        }

        emit Deposit(from, msg.sender, assets0, assets1, shares);
    }

    function withdraw(
        address to,
        uint256 shares,
        uint256 minAssets0Expected,
        uint256 minAssets1Expected
    ) external nonReentrant {
        // Gas savings
        address pair = address(this);
        uint256 totalShares = totalSupply();
        uint256 pairBalance = balanceOf(pair);
        // Always round in favor of liquidity providers
        uint256 assets0 = pairBalance.fullMulDiv(_reserves0, totalShares);
        uint256 assets1 = pairBalance.fullMulDiv(_reserves1, totalShares);
        require(
            _reserves0 > assets0 && _reserves1 > assets1,
            "PAIR: INSUFFICIENT_RESERVES"
        );
        require(
            assets0 >= minAssets0Expected && assets1 >= minAssets1Expected,
            "PAIR: WITHDRAW_SLIPPAGE_EXCEEDED"
        );

        _burn(to, shares);
        _update();

        // Don't execute 2 transfers if we only need 1
        if (assets0 > 0) {
            SafeTransferLib.safeTransferFrom(token0, pair, to, assets0);
        }
        if (assets1 > 0) {
            SafeTransferLib.safeTransferFrom(token1, pair, to, assets1);
        }

        emit Withdraw(to, msg.sender, assets0, assets1, shares);
    }

    function swap(
        address swapper,
        bool zeroForOne,
        uint256 inputAssets,
        uint256 minAssetsExpected
    ) external nonReentrant {
        address pair = address(this);
        (address input, address output, uint256 outputBalance) = zeroForOne
            ? (token0, token1, _reserves1)
            : (token1, token0, _reserves0);
        uint256 inputPrice = _price(zeroForOne, _reserves0, _reserves1);
        require(inputAssets > 0, "PAIR: NO_INPUT_ASSETS");

        uint256 grossOutputAssets = inputAssets * inputPrice;
        // Always round in favor of liquidity providers
        uint256 netOutputAssets = grossOutputAssets
            - grossOutputAssets.fullMulDivUp(swapFeeBasisPoints, 10000);
        require(outputBalance > netOutputAssets, "PAIR: INSUFFICIENT_RESERVES");
        require(
            netOutputAssets >= minAssetsExpected, "PAIR: SWAP_SLIPPAGE_EXCEEDED"
        );

        _update();

        SafeTransferLib.safeTransferFrom(input, swapper, pair, inputAssets);
        SafeTransferLib.safeTransferFrom(output, pair, swapper, netOutputAssets);

        emit Swap(swapper, msg.sender, inputAssets, netOutputAssets);
    }

    function loan(
        address borrower,
        uint256 assets0Borrowed,
        uint256 assets1Borrowed,
        bytes calldata data
    ) external nonReentrant {
        require(
            _reserves0 > assets0Borrowed && _reserves1 > assets1Borrowed,
            "PAIR: INSUFFICIENT_RESERVES"
        );
        address pair = address(this);

        if (assets0Borrowed > 0) {
            SafeTransferLib.safeTransferFrom(
                token0, pair, borrower, assets0Borrowed
            );
        }
        if (assets1Borrowed > 0) {
            SafeTransferLib.safeTransferFrom(
                token1, pair, borrower, assets1Borrowed
            );
        }

        IPairBorrower(borrower).onFlashLoan(
            msg.sender, assets0Borrowed, assets1Borrowed, data
        );

        uint256 balance0 = IERC20(token0).balanceOf(pair);
        uint256 balance1 = IERC20(token1).balanceOf(pair);
        uint256 assets0Returned = balance0 > (_reserves0 - assets0Borrowed)
            ? balance0 - _reserves0 - assets0Borrowed
            : 0;
        uint256 assets1Returned = balance1 > (_reserves1 - assets1Borrowed)
            ? balance1 - _reserves1 - assets1Borrowed
            : 0;
        require(
            assets0Returned > 0 || assets1Returned > 0,
            "PAIR: INSUFFICIENT_RETURNS"
        );

        uint256 requiredBalance0 =
            balance0 * 1000 - (assets0Returned * loanFeeBasisPoints);
        uint256 requiredBalance1 =
            balance1 * 1000 - (assets1Returned * loanFeeBasisPoints);
        require(
            requiredBalance0 * requiredBalance1
                >= _reserves0 * _reserves1 * (1000 ** 2),
            "PAIR: K"
        );

        _update();

        emit Loan(
            borrower,
            msg.sender,
            assets0Borrowed,
            assets1Borrowed,
            assets0Returned,
            assets1Returned
        );
    }

    function name() public view override returns (string memory) {
        return _name;
    }

    function symbol() public view override returns (string memory) {
        return _symbol;
    }

    function _update() internal {
        address pair = address(this);
        uint256 balance0 = IERC20(token0).balanceOf(pair);
        uint256 balance1 = IERC20(token1).balanceOf(pair);
        uint112 max112 = type(uint112).max;
        require(
            max112 >= balance0 && max112 >= balance1, "PAIR: BALANCE_OVERFLOW"
        );

        // Timestamp overflows uint32 in 02/07/2106
        // Since we mod it, the arithmetic below is actually safe
        // Oracles are required to check prices at least once every 136 years though.
        uint32 moddedTimestamp = uint32(block.timestamp % 2 ** 32);
        uint32 timeElapsed;
        unchecked {
            timeElapsed = moddedTimestamp - _lastUpdatedTimestamp;
        }

        if (timeElapsed > 0 && _reserves0 > 0 && _reserves1 > 0) {
            uint256 price0 = _price(true, _reserves0, _reserves1);
            uint256 price1 = _price(false, _reserves0, _reserves1);

            // uint224 * uint32 never overflows a uint256
            // (2^224 - 1) * (2^32 - 1) = 2^256 - 2^224 - 2^32 + 1
            // 2^256 - 1 > 2^256 - 2^224 - 2^32 + 1
            // QED
            unchecked {
                accumulatedPrice0 += price0 * timeElapsed;
                accumulatedPrice1 += price1 * timeElapsed;
            }
        }

        // We're already protected against overflow by the require above
        _reserves0 = uint112(balance0);
        _reserves1 = uint112(balance1);
        _lastUpdatedTimestamp = moddedTimestamp;

        emit Update(_reserves0, _reserves1);
    }

    function _price(bool zeroForOne, uint112 reserves0, uint112 reserves1)
        internal
        pure
        returns (uint256)
    {
        (uint224 encodedReserves0, uint224 encodedReserves1) =
            (uint224(reserves0), uint224(reserves1));

        // reserves are at most 2^112 - 1
        // Q112 * (2^112 - 1) never overflows a uint224
        // 2^112 * (2^112 - 1) = 2^224 - 2^112
        // 2^224 - 2^112 < 2^224 - 1
        // QED
        unchecked {
            return zeroForOne
                ? uint256((encodedReserves1 * Q112) / encodedReserves0)
                : uint256((encodedReserves0 * Q112) / encodedReserves1);
        }
    }
}
