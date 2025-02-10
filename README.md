# Vesting Contract with Multi-Signature Release

A smart contract for gradual token release with a multi-signature mechanism to ensure security.

## About the Project

This project implements a token vesting smart contract with a multi-signature mechanism. Tokens are locked for a beneficiary and released gradually according to a vesting schedule. Each token release requires approval from multiple authorized signers, providing an additional layer of security and governance.

## Key Features

- **Gradual Vesting**: Tokens are released gradually over time according to a linear vesting schedule.
- **Cliff Period**: Optional period during which no tokens are released.
- **Multi-Signature Release**: Token releases require approval from multiple authorized signers.
- **Revocable Vesting**: The owner can revoke the vesting schedule and reclaim unreleased tokens.
- **Signer Management**: The owner can add or remove signers and change the required number of approvals.

## Project Structure

- `src/VestingContract.sol`: The main vesting contract with multi-signature functionality.
- `src/MockToken.sol`: A simple ERC20 token implementation for testing purposes.
- `test/VestingContract.t.sol`: Tests for the vesting contract.
- `script/VestingContract.s.sol`: Script for deploying the contracts.

## Getting Started

### Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation.html)

### Installation

1. Clone the repository:
```bash
git clone https://github.com/KaiReytsu/multisig-vesting-contract.git
cd multisig-vesting-contract
```

2. Install dependencies:
```bash
forge install
```

## Testing

### Local Testing

Run the tests:
```bash
forge test
```

For more detailed output:
```bash
forge test -vvv
```

### Running a Local Node for Testing

1. Start a local Anvil node:
```bash
anvil
```

2. In a separate terminal, deploy the contracts to the local node:
```bash
# Export a private key from Anvil (use one of the displayed keys)
export PRIVATE_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80

# Run the deployment script
forge script script/VestingContract.s.sol:VestingContractScript --rpc-url http://localhost:8545 --broadcast
```

## Deploying to an EVM Network

### Deployment Preparation

1. Create a `.env` file with your keys and settings:
```
PRIVATE_KEY=your_private_key
ETHERSCAN_API_KEY=your_etherscan_key
```

2. Load the environment variables:
```bash
source .env
```

### Deploying to a Test Network (Sepolia)

```bash
forge script script/VestingContract.s.sol:VestingContractScript --rpc-url https://sepolia.infura.io/v3/YOUR_INFURA_KEY --broadcast --verify
```

### Deploying to Ethereum Mainnet

```bash
forge script script/VestingContract.s.sol:VestingContractScript --rpc-url https://mainnet.infura.io/v3/YOUR_INFURA_KEY --broadcast --verify
```

## Using the Contract

### Creating a Vesting Schedule

After deploying the contract:

1. Transfer tokens to the vesting contract address.
2. Add signers:
```solidity
vestingContract.addSigner(signer_address);
```

3. Create a vesting schedule:
```solidity
vestingContract.createVestingSchedule(
    beneficiary_address,
    total_amount,
    start_time,
    duration,
    cliff_period
);
```

### Requesting Token Release

A signer can request a token release:
```solidity
vestingContract.requestRelease(amount);
```

### Approving a Release

Other signers can approve the request:
```solidity
vestingContract.approveRelease(request_id);
```

### Revoking the Vesting Schedule

The owner can revoke the vesting schedule:
```solidity
vestingContract.revoke();
```

## Interacting via Etherscan or Other Blockchain Explorers

After deploying the contract to a network:

1. Find the contract address in a blockchain explorer (e.g., Etherscan).
2. Go to the "Contract" -> "Write Contract" tab.
3. Connect your wallet (MetaMask or other).
4. Use the interface to call the contract functions.

