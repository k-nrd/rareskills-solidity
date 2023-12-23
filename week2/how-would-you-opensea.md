# How would you keep track of NFT ownership if you were a marketplace?

Spin up a SQL database and a JSON-RPC API client (say, ethers.js running on Node). With the client up and running, listen to Transfer events emitted by whatever NFT contracts you are interested in, and update the database whenever adequate.

More specifically, we'd write a filter for the Transfer event, from block 0 to latest, and reduce over the results to bootstrap the database state - while also keeping track of block height in the database.

After that, we could poll (since we're using JSON-RPC, but we could subscribe instead if we were using GraphQL) for events every once in a while, from the last block recorded to latest. If the service ever went down for any reason, we'd restart the polling from the last block height recorded.

To track a new contract, first run the bootstrapping logic for it, and continue as normal.

This way, our database would always be a valid snapshot of the current ownership state, and depending on our table architecture we could even keep track of ownership history.
