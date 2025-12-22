# Reward Accumulator

A gas-optimized, mathematically rigorous staking rewards distribution system built with Solidity. This project implements a hierarchical reward accumulation mechanism that enables efficient multi-entity staking with continuous reward distribution.

## 🌟 Features

- **Three-Tier Architecture**: Global → Entity → Actor reward distribution
- **Continuous Rewards**: Mathematical accumulation using integral calculus principles
- **Gas Optimized**: Minimal storage reads/writes with checkpoint-based updates
- **Multi-Entity Support**: Stake across multiple entities with independent reward streams
- **Precision Handling**: 18-decimal precision for accurate reward calculations
- **No Rounding Errors**: Uses accumulator pattern to avoid loss from integer division

## 📐 Architecture

### Reward Accumulator Library

The `RewardAccumulator` library implements a three-level hierarchical accumulation system with **separated state and rate management** for optimal gas efficiency:

#### 1. Global Level

```solidity
G(t) = ∫ r1(t) dt
```

- Tracks global reward accumulation over time
- Rate: `1e17` (0.1 tokens per second per unit)
- Updates: `updateGlobalState()` accumulates rewards, `updateGlobalRate()` updates the rate
- Checkpoint: timestamp of last update

#### 2. Entity Level

```solidity
E(e,t) = ∫ r2(e,t) · dG
```

- Tracks entity reward accumulation based on global accumulator changes
- Rate: `1e17` (0.1 tokens per second base emission)
- Each entity's rate is proportional to its share: `ENTITY_EMISSION_RATE * entityStaked[e] / globalStaked`
- Entities with larger stakes accumulate more rewards from the global pool
- Updates: `updateEntityState()` accumulates rewards, `updateEntityRate()` updates the rate
- Checkpoint: global accumulator value at last update

#### 3. Actor Level

```solidity
A(a,e,t) = ∫ s(a,e,t) · dE
```

- Individual user (actor) rewards within an entity
- Proportional to actor's stake in the entity
- Updates: `updateActorState()` accumulates rewards and returns claimable amount
- Checkpoint: entity accumulator value at last update

### StakingRewards Contract

Main contract implementing the staking system:

- **Stake**: Deposit tokens to start earning rewards
- **Withdraw**: Remove staked tokens (automatically claims pending rewards)
- **Claim**: Collect accumulated rewards without unstaking

## 🚀 Getting Started

### Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation)

### Installation

```bash
git clone <repository-url>
cd reward-accumulator
forge install
```

### Build

```bash
forge build
```

### Test

```bash
# Run all tests
forge test

# Run with verbosity
forge test -vvv

# Run specific test
forge test --match-test testStake

# Run with gas reporting
forge test --gas-report
```

### Format

```bash
forge fmt
```

## 📊 Usage Example

```solidity
// Deploy contracts
StakingRewards staking = new StakingRewards(stakingToken, rewardToken);

// User stakes tokens to an entity
stakingToken.approve(address(staking), 1000e18);
staking.stake(entity, 1000e18);

// Check earned rewards
uint256 rewards = staking.earned(msg.sender, entity);

// Claim rewards
staking.claim(entity);

// Withdraw stake (also claims rewards)
staking.withdraw(entity, 1000e18);
```

## 🚢 Deployment

### Setup Environment

1. Copy `.env.example` to `.env`:

```bash
cp .env.example .env
```

2. Fill in your environment variables:

```bash
PRIVATE_KEY=your_private_key
RPC_URL=your_rpc_url
STAKING_TOKEN_ADDRESS=0x...
REWARD_TOKEN_ADDRESS=0x...
ETHERSCAN_API_KEY=your_api_key
```

### Deploy

```bash
# Dry run (simulation)
forge script script/StakingRewards.s.sol:StakingRewardsScript --rpc-url $RPC_URL

# Deploy to network
forge script script/StakingRewards.s.sol:StakingRewardsScript --rpc-url $RPC_URL --broadcast

# Deploy and verify
forge script script/StakingRewards.s.sol:StakingRewardsScript --rpc-url $RPC_URL --broadcast --verify
```

## 🧪 Testing

The project includes comprehensive tests covering:

- **RewardAccumulator.t.sol**: Tests for the reward accumulation library
- **StakingRewards.t.sol**: Integration tests for the staking contract

Run specific test suites:

```bash
forge test --match-contract RewardAccumulatorTest
forge test --match-contract StakingRewardsTest
```

## 📁 Project Structure

```
├── src/
│   ├── StakingRewards.sol          # Main staking contract
│   ├── interfaces/
│   │   └── IERC20.sol              # ERC20 interface
│   └── libraries/
│       └── RewardAccumulator.sol   # Core reward logic
├── test/
│   ├── RewardAccumulator.t.sol     # Library tests
│   ├── StakingRewards.t.sol        # Contract tests
│   └── mocks/
│       └── MockERC20.sol           # Mock ERC20 for testing
├── script/
│   └── StakingRewards.s.sol        # Deployment script
├── foundry.toml                    # Foundry configuration
└── .env.example                    # Environment template
```

## 🔍 Key Concepts

### Checkpoint System

The accumulator pattern uses checkpoints to avoid recalculating rewards from genesis:

- **Global Checkpoint**: Timestamp of last global update
- **Entity Checkpoint**: Global accumulator value at last entity update
- **Actor Checkpoint**: Entity accumulator value at last actor update
- **Rewards = Current Accumulator - Checkpoint**

### State vs Rate Updates

The system separates state updates (accumulation) from rate updates for efficiency:

- **State Updates**: `updateGlobalState()`, `updateEntityState()`, `updateActorState()` - accumulate rewards based on time/delta
- **Rate Updates**: `updateGlobalRate()`, `updateEntityRate()` - update the rate used for future accumulations

This separation allows the system to:

1. Accumulate rewards with the old rate before a stake change
2. Update the rate after a stake change without unnecessary reaccumulation
3. Minimize gas costs by avoiding redundant calculations

### Rate Calculations

**Global Rate**: Distributed across all staked tokens

```solidity
globalRate = GLOBAL_EMISSION_RATE * PRECISION / globalStaked
```

**Entity Rate**: Based on entity's share of total stake

```solidity
entityRate = ENTITY_EMISSION_RATE * entityStaked[e] / globalStaked
```

## ⚡ Gas Optimization

- Single storage update per sync operation
- Checkpoint-based calculations minimize computation
- View functions for gas-free reward queries
- Efficient accumulator updates using delta calculations

## 🔐 Security Considerations

- Reentrancy protection through checks-effects-interactions pattern
- Safe math operations (Solidity 0.8+ overflow protection)
- Require statements for input validation
- Immutable token addresses

## 📄 License

MIT

## 🛠️ Built With

- [Solidity ^0.8.26](https://docs.soliditylang.org/)
- [Foundry](https://book.getfoundry.sh/)

## 🤝 Contributing

Contributions, issues, and feature requests are welcome!

## 📚 Additional Resources

- [Foundry Book](https://book.getfoundry.sh/)
- [Solidity Documentation](https://docs.soliditylang.org/)

---

**Note**: This is a demonstration project. Ensure thorough auditing before using in production.
