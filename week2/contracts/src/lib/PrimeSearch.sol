// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

/// @title PrimeSearch Library
/// @notice Provides utility functions for prime number identification.
/// @dev Implements an optimized algorithm for checking if a given number is prime.
library PrimeSearch {
    /// @notice Determines if a given number is a prime number.
    /// @dev Utilizes a combination of simple checks and an optimized version of the wheel factorization technique to determine primality.
    ///      The function handles small numbers as special cases and uses bitwise operations for efficiency.
    /// @param number The number to check for primality.
    /// @return True if the number is prime, false otherwise.
    function isPrime(uint256 number) internal pure returns (bool) {
        if (number < 2) return false;
        // 2 and 3 are prime
        if (number < 4) return true;
        // Check if number is divisible by one of our basis elements
        if ((number & 1) == 0 || number % 3 == 0 || number % 5 == 0) return false;

        // We'll need to sieve for the number through eratosthenes + wheel factorization
        // k is our coprime
        uint256 k = 7;
        // We'll stop searching once k² >= number. Initialize to 7^2
        uint256 k2 = 49;
        // Our index into an array of increments according to wheel factorization
        uint256 j = 0;

        // Increments between consecutive elements of the wheel are always the same
        uint256[8] memory inc = [uint256(4), 2, 4, 2, 4, 6, 2, 6];

        while (k2 < number + 1) {
            // k is a factor of number, so it ain't prime
            if (number % k == 0) {
                return false;
            }

            // Keep turning the wheel
            k += inc[j];
            // Cheaper than squaring. Just + and *
            // newk2 = (oldk + inc[j]) ^ 2
            // newk2 = (oldk ^ 2) + (2 * oldk * inc[j]) + (inc[j] ^ 2)
            // newk2 = oldk2 + ((2 * oldk * inc[j]) + (inc[j] ^ 2))
            // oldk2 += (2 * oldk + inc[j]) * inc[j]
            // oldk2 += (2 * (k - inc[j]) + inc[j]) * inc[j]
            // oldk2 += (2 * k - inc[j]) * inc[j]
            k2 += (2 * k - inc[j]) * inc[j];
            j = (j + 1) % 8;
        }

        return true;
    }
}
