# Why does the SafeERC20 program exist?

ERC20 requires implementations to return boolean values for many operations, such as `transfer`, `approve` and `transferFrom`. SafeERC20 is a library that allows an ERC20 contract to interact safely with other ERC20 contracts, by checking the return values for external calls and reverting the transaction if they are failures.

Additionally, many token implementations do not follow the ERC20 spec and revert in case of failure instead of returning boolean values. SafeERC20 deals with these cases as well. It also provides helpers to increase or decrease allowances, mitigating front-running attacks that are made possible by the `approve/transferFrom` flow.
