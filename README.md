# tcap-one-sc
TCAP One Smart Contracts

Smart contracts are deployed in test network of Celo Blockchain and roll Up based Layer 2 infratructure Arbitrum respectively.
Currently the smart contracts are only to be used to store the information. The automation of the lending and borrowing is slated to be released in the 2nd phase.

## Features
* Debtmarket supporting invoices initially
* Invoices will be represented as NFTs
* Fractional ownership of the Invoices against investments in a single pool.
* Create Loan
* Issue Loan
* Lending
* Borrowing
* Repayments
* Distribution of principal and interest
* Anchoring of documents using IPFS content id

## Steps to setup and deploy the contracts

* npm install
* install truffle
* truffle console --network alfajores (it will deploy the code to alfajores test network of Celo Blockchain)
* truffle console --network arbitrum (it will deploy the code to rinkeby arbitrum test network)
* truffle test (Make sure ganache or local node is running)
