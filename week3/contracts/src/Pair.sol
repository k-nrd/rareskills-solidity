// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {ERC20} from "solady/tokens/ERC20.sol";
import {ReentrancyGuard} from "solady/utils/ReentrancyGuard.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {FixedPointMathLib} from "solady/utils/FixedPointMathLib.sol";

import {IERC20} from "openzeppelin/token/ERC20/IERC20.sol";
import {IERC3156FlashLender} from
    "openzeppelin/interfaces/IERC3156FlashLender.sol";
import {IERC3156FlashBorrower} from
    "openzeppelin/interfaces/IERC3156FlashBorrower.sol";

/// @title Automated Market Maker Pair Contract
/// @notice Implements an AMM with ERC20 token pairing, liquidity provision, swapping, and flash loan capabilities.
/// @dev Inherits functionality from ERC20, IERC3156FlashLender, and ReentrancyGuard.
contract Pair is ERC20, IERC3156FlashLender, ReentrancyGuard {
    using SafeTransferLib for *;
    using FixedPointMathLib for uint256;

    // Shared storage slots:
    // Q112, MINIMUM_SHARES
    // _reserves0, _reserves1, _lastUpdatedTimestamp
    // swapFeeBasisPoints, loanFeeBasisPoints

    /// @notice Fixed point factor for price calculation
    uint224 private constant Q112 = 2 ** 112;

    /// @notice Minimum shares constant to prevent attacks on initial liquidity add
    uint32 private constant MINIMUM_SHARES = 1e3;

    /// @notice Flash loan success return value
    bytes32 public constant FLASH_LOAN_SUCCESS =
        keccak256("ERC3156FlashBorrower.onFlashLoan");

    /// @notice The name of the pair
    string private _name;

    /// @notice The symbol of the pair
    string private _symbol;

    /// @notice Reserve amount of token0
    uint112 private _reserves0;

    /// @notice Reserve amount of token1
    uint112 private _reserves1;

    /// @notice Last updated timestamp for reserves
    uint32 private _lastUpdatedTimestamp;

    /// @notice Accumulated price of token0 used for oracle purposes
    uint256 public accumulatedPrice0;

    /// @notice Accumulated price of token1 used for oracle purposes
    uint256 public accumulatedPrice1;

    /// @notice Address of the first token of the pair
    address public immutable token0;

    /// @notice Address of the second token of the pair
    address public immutable token1;

    /// @notice Swap fee basis points for each swap transaction
    uint128 public immutable swapFeeBasisPoints;

    /// @notice Loan fee basis points for each flash loan transaction
    uint128 public immutable loanFeeBasisPoints;

    /// @notice Emitted when reserves are updated
    event Update(uint112 reserves0, uint112 reserves1);

    /// @notice Emitted on liquidity deposit
    event Deposit(
        address holder,
        address operator,
        uint256 amount0,
        uint256 amount1,
        uint256 sharesMinted
    );

    /// @notice Emitted on liquidity withdrawal
    event Withdraw(
        address holder,
        address operator,
        uint256 amount0,
        uint256 amount1,
        uint256 sharesBurned
    );

    /// @notice Emitted on swap execution
    event Swap(
        address swapper,
        address operator,
        uint256 inputAmount,
        uint256 outputAmount
    );

    /// @notice Emitted on successful flash loan transaction
    event Loan(
        address receiver,
        address operator,
        address token,
        uint256 amountBorrowed,
        uint256 amountReturned,
        bytes data
    );

    /// @notice Initializes a new AMM Pair contract
    /// @param name_ The name for the new pair token
    /// @param symbol_ The symbol for the new pair token
    /// @param token0_ The address of the first token in the pair
    /// @param token1_ The address of the second token in the pair
    /// @param swapFeeBasisPoints_ The swap fee in basis points (1 basis point = 0.01%)
    /// @param loanFeeBasisPoints_ The loan fee in basis points for flash loans
    /// @dev Sets the immutable variables for the contract and ensures proper setup
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

    /// @notice Deposits amount into the pool in exchange for liquidity shares
    /// @param from Address from which amount will be transferred
    /// @param amount0 Amount of token0 to deposit
    /// @param amount1 Amount of token1 to deposit
    /// @param minSharesExpected Minimum number of shares expected to mint
    /// @dev Emits a Deposit event upon successful deposit
    function deposit(
        address from,
        uint256 amount0,
        uint256 amount1,
        uint256 minSharesExpected
    ) external nonReentrant {
        // Either msg.sender is the owner or they have allowance on tokens
        require(
            msg.sender == from
                || (
                    IERC20(token0).allowance(from, msg.sender) >= amount0
                        && IERC20(token1).allowance(from, msg.sender) >= amount1
                ),
            "PAIR: INSUFFICIENT_ALLOWANCE"
        );

        // Gas savings
        address pair = address(this);
        uint256 totalShares = totalSupply();
        uint256 shares;
        // Calculate how many shares they should get
        if (totalShares == 0) {
            require(amount0 > 0 && amount1 > 0, "PAIR: INVALID_FIRST_MINT");
            // We haven't minted any shares yet
            shares = (amount0 * amount1).sqrt() - MINIMUM_SHARES;
            // Mint minimum liquidity, this mitigates donation attacks
            _mint(address(0), MINIMUM_SHARES);
        } else {
            // Always round in favor of liquidity providers
            shares = amount0.fullMulDiv(totalShares, _reserves0).min(
                amount1.fullMulDiv(totalShares, _reserves1)
            );
        }
        require(shares >= minSharesExpected, "PAIR: DEPOSIT_SLIPPAGE_EXCEEDED");

        _mint(from, shares);

        emit Deposit(from, msg.sender, amount0, amount1, shares);

        // Don't execute 2 transfers if we only need 1
        if (amount0 > 0) {
            IERC20(token0).transferFrom(from, pair, amount0);
            // SafeTransferLib.safeTransferFrom(token0, from, pair, amount0);
        }
        if (amount1 > 0) {
            IERC20(token1).transferFrom(from, pair, amount1);
            // SafeTransferLib.safeTransferFrom(token1, from, pair, amount1);
        }

        _update();
    }

    /// @notice Withdraws amount from the pool by burning liquidity shares
    /// @param to Address where withdrawn amount will be transferred
    /// @param shares Number of liquidity shares to burn
    /// @param minAmount0Expected Minimum amount of token0 expected to prevent slippage
    /// @param minAmount1Expected Minimum amount of token1 expected to prevent slippage
    /// @dev Emits a Withdraw event upon successful withdrawal
    function withdraw(
        address to,
        uint256 shares,
        uint256 minAmount0Expected,
        uint256 minAmount1Expected
    ) external nonReentrant {
        // Either msg.sender is the owner or they have allowance on shares
        require(
            msg.sender == to || allowance(to, msg.sender) >= shares,
            "PAIR: INSUFFICIENT_ALLOWANCE"
        );

        // Gas savings
        address pair = address(this);
        uint256 totalShares = totalSupply();
        uint256 pairBalance = balanceOf(pair);
        // Always round in favor of liquidity providers
        uint256 amount0 = pairBalance.fullMulDiv(_reserves0, totalShares);
        uint256 amount1 = pairBalance.fullMulDiv(_reserves1, totalShares);
        require(
            _reserves0 > amount0 && _reserves1 > amount1,
            "PAIR: INSUFFICIENT_RESERVES"
        );
        require(
            amount0 >= minAmount0Expected && amount1 >= minAmount1Expected,
            "PAIR: WITHDRAW_SLIPPAGE_EXCEEDED"
        );

        _burn(to, shares);

        emit Withdraw(to, msg.sender, amount0, amount1, shares);

        // Don't execute 2 transfers if we only need 1
        if (amount0 > 0) {
            IERC20(token0).transfer(to, amount0);
            // SafeTransferLib.safeTransfer(token0, to, amount0);
        }
        if (amount1 > 0) {
            IERC20(token1).transfer(to, amount1);
            // SafeTransferLib.safeTransfer(token1, to, amount1);
        }

        _update();
    }

    /// @notice Swaps an amount of one token for an amount of the other token
    /// @param swapper Address executing the swap
    /// @param zeroForOne Direction of swap (true for token0 to token1, false for token1 to token0)
    /// @param inputAmount Amount of input token
    /// @param minAmountExpected Minimum amount of output token expected to prevent slippage
    /// @dev Emits a Swap event upon successful swap
    function swap(
        address swapper,
        bool zeroForOne,
        uint256 inputAmount,
        uint256 minAmountExpected
    ) external nonReentrant {
        require(inputAmount > 0, "PAIR: NO_INPUT_AMOUNT");

        // Gas savings
        (
            address input,
            address output,
            uint256 inputBalance,
            uint256 outputBalance
        ) = zeroForOne
            ? (token0, token1, _reserves0, _reserves1)
            : (token1, token0, _reserves1, _reserves0);
        // Either msg.sender is the owner or they have allowance on input tokens
        require(
            msg.sender == swapper
                || IERC20(input).allowance(swapper, msg.sender) >= inputAmount,
            "PAIR: INSUFFICIENT_ALLOWANCE"
        );

        // We need non-zero input reserves to calculate the price
        require(inputBalance > 0, "PAIR: NO_INPUT_RESERVES");
        uint256 inputPrice = _price(zeroForOne, _reserves0, _reserves1);

        // Always round in favor of liquidity providers
        uint256 grossOutputAmount = inputAmount.fullMulDiv(inputPrice, Q112);
        uint256 netOutputAmount = grossOutputAmount
            - grossOutputAmount.fullMulDivUp(swapFeeBasisPoints, 1e4);

        require(outputBalance > netOutputAmount, "PAIR: INSUFFICIENT_RESERVES");
        require(
            netOutputAmount >= minAmountExpected, "PAIR: SWAP_SLIPPAGE_EXCEEDED"
        );

        emit Swap(swapper, msg.sender, inputAmount, netOutputAmount);

        // Gas savings
        address pair = address(this);
        // IERC20(input).transferFrom(swapper, pair, inputAmount);
        // IERC20(output).transfer(swapper, netOutputAmount);
        SafeTransferLib.safeTransferFrom(input, swapper, pair, inputAmount);
        SafeTransferLib.safeTransfer(output, swapper, netOutputAmount);

        _update();
    }

    /// @notice Provides the maximum flash loan amount for a specific token
    /// @param token Address of the token for which the max loan amount is queried
    /// @return The maximum amount of the token that can be loaned
    function maxFlashLoan(address token) external view returns (uint256) {
        if (token == token0) return _reserves0;
        if (token == token1) return _reserves1;
        return 0;
    }

    /// @notice Calculates the fee for a flash loan of a specific amount of a given token
    /// @param token Address of the token for which the fee is calculated
    /// @param amount Amount of the token to be loaned
    /// @return The fee amount for the flash loan
    function flashFee(address token, uint256 amount)
        external
        view
        returns (uint256)
    {
        require(token == token0 || token == token1, "PAIR: INVALID_TOKEN");
        return amount.fullMulDivUp(uint256(loanFeeBasisPoints), 10000);
    }

    /// @notice Executes a flash loan transaction
    /// @param receiver Address of the flash loan receiver contract
    /// @param token Address of the token to be loaned
    /// @param amount Amount of the token to be loaned
    /// @param data Arbitrary data payload to be sent to the receiver contract
    /// @return True if the flash loan is executed successfully
    /// @dev Emits a Loan event upon successful flash loan
    function flashLoan(
        IERC3156FlashBorrower receiver,
        address token,
        uint256 amount,
        bytes calldata data
    ) external nonReentrant returns (bool) {
        require(amount > 0, "PAIR: INVALID_LOAN");

        bool isTokenZero = token == token0;
        bool isTokenOne = token == token1;
        require(isTokenZero || isTokenOne, "PAIR: INVALID_TOKEN");

        uint112 reserves = isTokenZero ? _reserves0 : _reserves1;
        require(reserves > amount, "PAIR: INSUFFICIENT_RESERVES");

        address pair = address(this);
        IERC20(token).transferFrom(pair, address(receiver), amount);
        // SafeTransferLib.safeTransferFrom(token, pair, address(receiver), amount);

        require(
            IERC3156FlashBorrower(receiver).onFlashLoan(
                msg.sender, token, amount, loanFeeBasisPoints, data
            ) == FLASH_LOAN_SUCCESS,
            "PAIR: FLASH_LOAN_FAILED"
        );

        uint256 balance = IERC20(token).balanceOf(pair);
        uint256 amountReturned =
            balance > (reserves - amount) ? balance - reserves - amount : 0;
        require(amountReturned > 0, "PAIR: INSUFFICIENT_RETURNS");

        uint256 requiredBalance =
            balance * 1000 - (amountReturned * loanFeeBasisPoints);
        require(requiredBalance >= reserves * 1000, "PAIR: LIQUIDITY_DECREASED");

        _update();

        emit Loan(
            address(receiver), msg.sender, token, amount, amountReturned, data
        );

        return true;
    }

    /// @notice Returns the name of the token pair
    /// @return Name of the token pair
    function name() public view override returns (string memory) {
        return _name;
    }

    /// @notice Returns the symbol of the token pair
    /// @return Symbol of the token pair
    function symbol() public view override returns (string memory) {
        return _symbol;
    }

    /// @notice Updates the reserves and prices for oracle functionality
    /// @dev Should be called after any token transfer in the pool
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

    /// @notice Calculates the price of one token in terms of the other
    /// @param zeroForOne Direction of price calculation (true for price of token0 in terms of token1, false for the reverse)
    /// @param reserves0 Current reserve of token0
    /// @param reserves1 Current reserve of token1
    /// @return Price of one token in terms of the other
    /// @dev Uses fixed-point arithmetic for price calculation
    function _price(bool zeroForOne, uint112 reserves0, uint112 reserves1)
        internal
        pure
        returns (uint256)
    {
        (uint224 r0, uint224 r1) = (uint224(reserves0), uint224(reserves1));
        // reserves are at most 2^112 - 1
        // Q112 * (2^112 - 1) never overflows a uint224
        // 2^112 * (2^112 - 1) = 2^224 - 2^112
        // 2^224 - 2^112 < 2^224 - 1
        // QED
        unchecked {
            return
                zeroForOne ? uint256(r1 * Q112 / r0) : uint256(r0 * Q112 / r1);
        }
    }
}
