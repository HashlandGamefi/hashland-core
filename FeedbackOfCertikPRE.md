## HCH-01 | Initial token distribution

According to our white paper, the total amount of HC tokens is 21 million. When deploying the contract, 2.1 million will be pre-mined to the multi-signature wallet of the board of directors.

## HCH-02 | Lack of sanity check in function subWeight()

This issue has been resolved in this commit.

## HCH-03 | Centralization Risk

We will use a multi-signature wallet to manage `DEFAULT_ADMIN_ROLE` and `MANAGER_ROLE`.

## HCH-04 | Missing emit events

This issue has been resolved in this commit.

## HCL-01 | Unchecked Value of ERC-20 transfer()/transferFrom() Call

This issue has been resolved in this commit.

## HCL-02 | Centralization Risk

We will use a multi-signature wallet to manage `DEFAULT_ADMIN_ROLE` and `MANAGER_ROLE`.

## HNB-01 | Lack of sanity check in function buyBoxes()

This issue has been resolved in this commit.

## HNB-02 | Unchecked Value of ERC-20 transfer()/transferFrom() Call

This issue has been resolved in this commit.

## HNB-03 | Centralization Risk

We will use a multi-signature wallet to manage `DEFAULT_ADMIN_ROLE` and `MANAGER_ROLE`.

## HNB-04 | Admin can mint tokens for free

This issue has been resolved in this commit.

## HNB-05 | Function adminBuyBoxes() does not accumulate totalBoxesLength

This issue has been resolved in this commit.

## HNH-01 | Weak pseudo random number generator

This function is designed to generate random numbers based on `hnId` and `slot`. For example, the `class` attribute(range 1-4) of the NFT with ID `3` is always `2`.

## HNH-02 | Centralization Risk

We will use a multi-signature wallet to manage `DEFAULT_ADMIN_ROLE`.
`SPAWNER_ROLE` will be granted to the HNBox contract.
`SETTER_ROLE` will be granted to the HNUpgrade contract.

## HNM-01 | Unchecked Value of ERC-20 transfer()/transferFrom() Call

This issue has been resolved in this commit.

## HNM-02 | Centralization Risk

We will use a multi-signature wallet to manage `DEFAULT_ADMIN_ROLE` and `MANAGER_ROLE`.
`HNPOOL_ROLE` will be granted to the HNPool contract.

## HNM-03 | No upper limit for feeRate

This issue has been resolved in this commit.

## HNP-01 | Unchecked Value of ERC-20 transfer()/transferFrom() Call

This issue has been resolved in this commit.

## HNP-02 | Logical issue of function airdropTokens()

We will ensure that tokens will only be airdropped once a day based on the `lastAirdropTimes`.

## HNP-03 | Centralization Risk

We will use a multi-signature wallet to manage `DEFAULT_ADMIN_ROLE`, `MANAGER_ROLE` and `AIRDROPPER_ROLE`.
`hnMarket` will be granted to the HNMarket contract.

## HNP-04 | Logical issue of function setMaxSlots()

This issue has been resolved in this commit.

## HNP-05 | Insufficient Reward Distribution

Because the time of the daily airdrop of tokens cannot be guaranteed to always be the same, it is necessary to give priority to ensuring that the user's daily income is constant. We will ensure that tokens are airdropped once a day.

## HNU-01 | Unchecked Value of ERC-20 transfer()/transferFrom() Call

This issue has been resolved in this commit.

## HNU-02 | Centralization Risk

We will use a multi-signature wallet to manage `DEFAULT_ADMIN_ROLE` and `MANAGER_ROLE`.

## HNU-03 | Function upgrade() does not check the ownership of material tokens

This issue has been resolved in this commit.

## IPH-01 | Unchecked Value of ERC-20 transfer()/transferFrom() Call

This issue has been resolved in this commit.

## IPH-02 | Centralization Risk

We will use a multi-signature wallet to manage `DEFAULT_ADMIN_ROLE` and `MANAGER_ROLE`.
`HNPOOL_ROLE` will be granted to the HNPool contract.