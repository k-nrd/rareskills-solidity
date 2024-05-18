# How does ERC721A save gas?

ERC721A saves gas by optimizing batch mints. The end result is that when users mint more than 1 token (which is a very common use case), batch minting saves a lot of gas compared to minting them one by one.

It achieves this by:

1. Updating an user's balance only once per batch mint, instead of once every mint.
2. Updating ownership data only once per batch mint, instead of once every mint.

While 2 is simple to understand and imagine an implementation for, 1 uses a linked-list scheme to ownership data, where a token token that has an owner set is the head and following tokens that do not have an owner set are the tail. One can figure out who is the owner of a token by checking if it has an owner set or not - if not, go backwards in the token list until you find one that has an owner, and that's the address you were looking for.

# Where does ERC721A spend extra gas?

On every transfer or check for ownership, one has to traverse a linked-list and find its head in order to find the token's current owner. Additionally, in worst-case scenario transfers, two writes might be necessary - one to write the new owner of the transferred token, and another one to write the current owner of the following token, if it did not have an owner set (meaning it's owned by the address that owns the head of the token linked-list and we now have to set that explicitly).
