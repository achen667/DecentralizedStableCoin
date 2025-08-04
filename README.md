# Decentralized StableCoin (DSC)

> A minimal, overcollateralized, algorithmic stablecoin system inspired by MakerDAO's DAI but simplified and trust-minimized.

##  Overview

This project implements a decentralized stablecoin system that maintains a **1:1 peg with USD**, backed by **crypto collateral (WETH, WBTC)**. It ensures **overcollateralization**, preventing the stablecoin supply from exceeding the USD value of locked collateral.

Key features:

-  Exogenously collateralized (uses crypto tokens like WETH/WBTC)
-  Dollar-pegged with oracle-based price feeds
-  Algorithmically stable (no governance or fees)
-  Fully open-source and testable via [Foundry](https://book.getfoundry.sh)

---

##  Project Structure


```

├── src/  
│ ├── DSCEngine.sol # Core stablecoin logic (mint/redeem/liquidation)  
│ └── DecentralizedStableCoin.sol # ERC20 token (burnable, mintable by engine)  
├── script/  
│ └── DeployDSC.s.sol # Deployment script  
├── test/ # Unit & invariant tests  
├── lib/ # External libraries (via forge install)  
├── foundry.toml # Foundry config file  
└── Makefile # Task runner for common actions

```

---

##  Requirements

- [Foundry](https://book.getfoundry.sh/getting-started/installation) (Forge & Cast)
- `.env` file (optional) with:

```env
SEPOLIA_RPC_URL=<your_sepolia_rpc_url>
ACCOUNT=<your_private_key>
ETHERSCAN_API_KEY=<your_etherscan_api_key>

```

----------

##  Deployment

### Local (Anvil):

```bash
make anvil
make deploy

```

### Sepolia:

```bash
make deploy ARGS="--network sepolia"

```

> This deploys the `DSCEngine` and `DecentralizedStableCoin` contracts and verifies them on Etherscan (if API key provided).

----------

##  Features

### Deposit Collateral

```solidity
dscEngine.depositCollateral(wethAddress, 100e18);

```

### Mint DSC

```solidity
dscEngine.mintDSC(50e18);

```

### Burn and Redeem

```solidity
dscEngine.redeemCollateralAndBurnDSC(weth, 100e18, 50e18);

```

### Liquidation

If a user falls below the required health factor (collateral value / debt):

```solidity
dscEngine.liquidate(weth, user, debtToCover);

```

----------

##  Access Control

Only the `DSCEngine` can mint or burn DSC. This is enforced via OpenZeppelin's `Ownable` in `DecentralizedStableCoin`.

----------

##  Testing

Run full unit and invariant tests:

```bash
make test

```

Test with logs and traces:

```bash
forge test -vvvv

```

Check test coverage:

```bash
make coverage

```

----------

##  Invariant Testing

Tests assumptions like:

-   Protocol is always overcollateralized
    
-   Collateral + bonus can't be overdrawn
    
-   Health factor improves post-liquidation
    

> See: `test/fuzz/InvariantsTest.t.sol`

----------

##  Commands (Makefile)

```bash
make clean       # Clean the repo
make update      # Update dependencies
make deploy      # Deploy contract
make anvil       # Start local testnet
make test        # Run tests
make snapshot    # Create state snapshot
make format      # Format code with forge fmt

```
