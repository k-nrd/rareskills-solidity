# Uniswap TWAP

## Why do we let cumulative prices overflow?

Reserves are stored in uint112s, and prices are calculated as a ratio of reserves in UQ112.112 fixed-point number.
This means prices always fit in an uint224. The accumulated prices, however are stored in an uint256, meaning any extra
bits are overflow bits when interpreted as UQ112.112s. 

By taking these overflow bits into account, one can just use arithmetic to figure out the correct time-weighted average 
price over a given period.

## How can you use the oracle?

Pick a token and store its cumulative price on time T1. Store again on time T2.
Check if the cumulative price has overflowed and adjust one of the two versions so the difference is correct.
Take the difference between cumulative prices on T1 and T2, divide by the difference of T1 and T2.
You've got the time-weighted average price for your selected token.


## Why are cumulative prices stored separately?

We could try instead to store a single accumulated price over a period. Let's call the arithmetic (time-weighted) mean price of that price over a period A1.
The reciprocal arithmetic mean price of the other asset over the same period would *not* be 1/A1. Instead, 1/A1 would be the harmonic mean price of the other asset. There is no reasonable way of getting from a harmonic mean to an arithmetic mean, and thus this would not work.

As of Uniswap V3, the oracle functionality now uses accumulated log prices, allowing the users to compute a geometric mean of both assets in a single go, 
since 1/G1 (where G1 is the geometric mean of a given price over a given period) would be equal to G2 (and 1/G2 = G1).

