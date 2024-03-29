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
    using SafeTransferLib for address;
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

    /// @notice Address of factory contract
    /// @dev Current value is useful for testing, should be changed
    address public constant FACTORY_ADDRESS =
        address(0xF62849F9A0B5Bf2913b396098F7c7019b51A820a);

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
    address public immutable TOKEN_0;

    /// @notice Address of the second token of the pair
    address public immutable TOKEN_1;

    /// @notice Swap fee basis points for each swap transaction
    uint128 public immutable SWAP_FEE_BASIS_POINTS;

    /// @notice Loan fee basis points for each flash loan transaction
    uint128 public immutable LOAN_FEE_BASIS_POINTS;

    /// @notice Error for when the caller is not the factory
    error InvalidFactory();

    /// @notice Error for when the first minting of liquidity shares is invalid (zero amounts)
    error InvalidFirstMint();

    /// @notice Error for when an invalid input is provided (e.g., zero amount)
    error InvalidInput();

    /// @notice Error for when the token specified is not valid for the pair
    error InvalidToken();

    /// @notice Error for when there are insufficient reserves for the operation
    error InsufficientReserves();

    /// @notice Error for when the returned amount from an operation is insufficient
    error InsufficientReturns();

    /// @notice Error for when the slippage is too high in a liquidity or swap operation
    error SlippageExceeded();

    /// @notice Error for when a flash loan fails to execute properly
    error LoanFailed();

    /// @notice Error for when a balance exceeds the maximum uint112 value, causing an overflow
    error ReservesOverflow();

    /// @notice Emitted when reserves are updated
    event Update(uint112 reserves0, uint112 reserves1);

    /// @notice Emitted on liquidity deposit
    event Deposit(
        address depositor,
        address beneficiary,
        uint256 amount0,
        uint256 amount1,
        uint256 sharesMinted
    );

    /// @notice Emitted on liquidity withdrawal
    event Withdraw(
        address holder,
        address beneficiary,
        uint256 amount0,
        uint256 amount1,
        uint256 sharesBurned
    );

    /// @notice Emitted on swap execution
    event Swap(
        address swapper,
        address receiver,
        uint256 inputAmount,
        uint256 outputAmount
    );

    /// @notice Emitted on successful flash loan transaction
    event Loan(
        address receiver,
        address operator,
        address token,
        uint256 amountBorrowed,
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
        if (msg.sender != FACTORY_ADDRESS) revert InvalidFactory();
        if (token0_ == address(0) || token1_ == address(0)) {
            revert InvalidInput();
        }
        _name = name_;
        _symbol = symbol_;

        TOKEN_0 = token0_;
        TOKEN_1 = token1_;
        SWAP_FEE_BASIS_POINTS = swapFeeBasisPoints_;
        LOAN_FEE_BASIS_POINTS = loanFeeBasisPoints_;
    }

    /// @notice Deposits amount into the pool in exchange for liquidity shares
    /// @param beneficiary Recipient of shares
    /// @param amount0 Amount of token0 to deposit
    /// @param amount1 Amount of token1 to deposit
    /// @param minSharesExpected Minimum number of shares expected to mint
    //  @return Number of shares minted
    /// @dev Emits a Deposit event upon successful deposit
    function deposit(
        address beneficiary,
        uint256 amount0,
        uint256 amount1,
        uint256 minSharesExpected
    ) external nonReentrant returns (uint256) {
        // Gas savings
        address pair = address(this);

        if (
            IERC20(TOKEN_0).allowance(msg.sender, pair) < amount0
                || IERC20(TOKEN_1).allowance(msg.sender, pair) < amount1
        ) {
            revert InsufficientAllowance();
        }

        uint256 totalShares = totalSupply();
        uint256 shares;
        // Calculate how many shares they should get
        if (totalShares == 0) {
            if (amount0 == 0 || amount1 == 0) revert InvalidFirstMint();
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
        if (shares < minSharesExpected) revert SlippageExceeded();

        _mint(beneficiary, shares);

        emit Deposit(msg.sender, beneficiary, amount0, amount1, shares);

        // Don't execute 2 transfers if we only need 1
        if (amount0 > 0) {
            TOKEN_0.safeTransferFrom(msg.sender, pair, amount0);
        }
        if (amount1 > 0) {
            TOKEN_1.safeTransferFrom(msg.sender, pair, amount1);
        }

        _update();

        return shares;
    }

    /// @notice Withdraws amount from the pool by burning liquidity shares
    /// @param beneficiary Tokens recipient
    /// @param shares Number of liquidity shares to burn
    /// @param minAmount0Expected Minimum amount of token0 expected to prevent slippage
    /// @param minAmount1Expected Minimum amount of token1 expected to prevent slippage
    /// @return Number of tokens returned for each token of the pair
    /// @dev Emits a Withdraw event upon successful withdrawal
    function withdraw(
        address beneficiary,
        uint256 shares,
        uint256 minAmount0Expected,
        uint256 minAmount1Expected
    ) external nonReentrant returns (uint256, uint256) {
        // Gas savings
        uint256 totalShares = totalSupply();
        // Always round in favor of liquidity providers
        uint256 amount0 = shares.fullMulDiv(_reserves0, totalShares);
        uint256 amount1 = shares.fullMulDiv(_reserves1, totalShares);
        if (_reserves0 <= amount0 || _reserves1 <= amount1) {
            revert InsufficientReserves();
        }
        if (amount0 < minAmount0Expected || amount1 < minAmount1Expected) {
            revert SlippageExceeded();
        }

        _burn(msg.sender, shares);

        emit Withdraw(msg.sender, beneficiary, amount0, amount1, shares);

        // We'll almost always execute two transfers
        TOKEN_0.safeTransfer(beneficiary, amount0);
        TOKEN_1.safeTransfer(beneficiary, amount1);

        _update();

        return (amount0, amount1);
    }

    /// @notice Swaps an amount of one token for an amount of the other token
    /// @param receiver Recipient of swapped tokens
    /// @param zeroForOne Direction of swap (true for token0 to token1, false for token1 to token0)
    /// @param inputAmount Amount of input token
    /// @param minAmountExpected Minimum amount of output token expected to prevent slippage
    /// @dev Emits a Swap event upon successful swap
    function swap(
        address receiver,
        bool zeroForOne,
        uint256 inputAmount,
        uint256 minAmountExpected
    ) external nonReentrant {
        if (inputAmount == 0) revert InvalidInput();

        // Gas savings
        address pair = address(this);
        (
            address input,
            address output,
            uint256 inputBalance,
            uint256 outputBalance
        ) = zeroForOne
            ? (TOKEN_0, TOKEN_1, _reserves0, _reserves1)
            : (TOKEN_1, TOKEN_0, _reserves1, _reserves0);

        // We also need to have allowance on the input token
        if (IERC20(input).allowance(msg.sender, pair) < inputAmount) {
            revert InsufficientAllowance();
        }

        // We need non-zero input reserves to calculate the price
        if (inputBalance == 0) revert InsufficientReserves();
        uint256 inputPrice = _price(zeroForOne, _reserves0, _reserves1);

        // Always round in favor of liquidity providers
        uint256 grossOutputAmount = inputAmount.fullMulDiv(inputPrice, Q112);
        uint256 netOutputAmount = grossOutputAmount
            - grossOutputAmount.fullMulDivUp(SWAP_FEE_BASIS_POINTS, 1e4);

        if (outputBalance <= netOutputAmount) revert InsufficientReserves();
        if (netOutputAmount < minAmountExpected) revert SlippageExceeded();

        emit Swap(msg.sender, receiver, inputAmount, netOutputAmount);

        input.safeTransferFrom(msg.sender, pair, inputAmount);
        output.safeTransfer(receiver, netOutputAmount);

        _update();
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
        if (amount == 0) revert InvalidInput();
        if (token != TOKEN_0 && token != TOKEN_1) revert InvalidToken();

        (IERC20 otherToken, uint112 borrowedReserves, uint112 otherReserves) =
        token == TOKEN_0
            ? (IERC20(TOKEN_1), _reserves0, _reserves1)
            : (IERC20(TOKEN_0), _reserves1, _reserves0);

        if (borrowedReserves < amount) revert InsufficientReserves();

        (address pair, address borrower) = (address(this), address(receiver));

        // Check allowance and transfer
        if (IERC20(token).allowance(pair, borrower) < amount) {
            token.safeApprove(borrower, amount);
        }
        token.safeTransfer(borrower, amount);

        if (
            IERC3156FlashBorrower(receiver).onFlashLoan(
                msg.sender, token, amount, LOAN_FEE_BASIS_POINTS, data
            ) != FLASH_LOAN_SUCCESS
        ) revert LoanFailed();

        if (
            IERC20(token).balanceOf(pair) * otherToken.balanceOf(pair)
                < (borrowedReserves + _flashFee(amount)) * otherReserves
        ) {
            revert InsufficientReturns();
        }

        // This function is nonReentrant
        // slither-disable-start reentrancy-no-eth
        // slither-disable-start reentrancy-benign
        _update();
        // slither-disable-end reentrancy-no-eth
        // slither-disable-end reentrancy-benign

        emit Loan(address(receiver), msg.sender, token, amount, data);

        return true;
    }

    /// @notice Provides the maximum flash loan amount for a specific token
    /// @param token Address of the token for which the max loan amount is queried
    /// @return The maximum amount of the token that can be loaned
    function maxFlashLoan(address token) external view returns (uint256) {
        // TODO: not quite correct
        if (token == TOKEN_0) return _reserves0;
        if (token == TOKEN_1) return _reserves1;
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
        if (token != TOKEN_0 && token != TOKEN_1) revert InvalidToken();
        return _flashFee(amount);
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
        uint256 balance0 = IERC20(TOKEN_0).balanceOf(pair);
        uint256 balance1 = IERC20(TOKEN_1).balanceOf(pair);
        uint112 max112 = type(uint112).max;
        if (max112 < balance0 || max112 < balance1) {
            revert ReservesOverflow();
        }

        // Timestamp overflows uint32 in 02/07/2106
        // Since we mod it, the arithmetic below is actually safe
        // Oracles are required to check prices at least once every 136 years though.
        // slither-disable-next-line weak-prng
        uint32 moddedTimestamp = uint32(block.timestamp % 2 ** 32);
        uint32 timeElapsed;
        unchecked {
            timeElapsed = moddedTimestamp - _lastUpdatedTimestamp;
        }

        // slither-disable-next-line timestamp
        if (timeElapsed > 0 && _reserves0 > 0 && _reserves1 > 0) {
            uint256 price0 = _price(true, _reserves0, _reserves1);
            uint256 price1 = _price(false, _reserves0, _reserves1);

            // accumulatedPrices can overflow, and
            // price * timeElapsed can't overflow a uint256, proof below
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

    /// @notice Calculates the fee for a flash loan
    /// @param amount Amount of the token to be loaned
    /// @return The fee amount for the flash loan
    function _flashFee(uint256 amount) internal view returns (uint256) {
        return amount.fullMulDivUp(uint256(LOAN_FEE_BASIS_POINTS), 1e4);
    }

    /// @notice Calculates the price of one token in terms of the other
    /// @param zeroForOne Direction of price calculation
    ///        (true for price of token0 in terms of token1, false for the reverse)
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
