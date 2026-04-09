// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IERC20} from "src/interfaces/IERC20.sol";

import {RewardAccumulator} from "src/libraries/RewardAccumulator.sol";

contract StakingRewards {
    using RewardAccumulator for RewardAccumulator.Global;
    using RewardAccumulator for RewardAccumulator.Entity;
    using RewardAccumulator for RewardAccumulator.Actor;

    IERC20 public immutable STAKING_TOKEN;
    IERC20 public immutable REWARD_TOKEN;

    bool private _locked;

    /* ================= STAKING ================= */

    uint256 public globalStaked; // staked
    mapping(address => uint256) public entityStaked; // entity => staked
    mapping(address => mapping(address => uint256)) public actorStaked; // actor => entity => stake
    mapping(address => mapping(address => uint256)) public actorPaid; // actor => entity => paid

    /* ================= REWARDS ================= */

    RewardAccumulator.Global public global;
    mapping(address => RewardAccumulator.Entity) public entities;
    mapping(address => mapping(address => RewardAccumulator.Actor)) public actors;

    /* ================= EVENTS ================= */

    event Staked(address indexed actor, address indexed entity, uint256 amount);
    event Withdrawn(address indexed actor, address indexed entity, uint256 amount);
    event Claimed(address indexed actor, address indexed entity, uint256 reward);

    /* ================= CONSTRUCTOR ================= */

    constructor(address stakingTokenAddress, address rewardTokenAddress) {
        require(stakingTokenAddress != address(0), "invalid staking token");
        require(rewardTokenAddress != address(0), "invalid reward token");

        STAKING_TOKEN = IERC20(stakingTokenAddress);
        REWARD_TOKEN = IERC20(rewardTokenAddress);

        _syncGlobalRate();
    }

    /* ================= MODIFIERS ================= */

    modifier nonReentrant() {
        require(!_locked, "reentrant call");
        _locked = true;
        _;
        _locked = false;
    }

    /* ================= USER ACTIONS ================= */

    function stake(address entity, uint256 amount) external nonReentrant {
        require(entity != address(0), "invalid entity");
        require(amount > 0, "amount = 0");

        _syncActorState(msg.sender, entity);

        require(STAKING_TOKEN.transferFrom(msg.sender, address(this), amount), "transferFrom failed");

        actorStaked[msg.sender][entity] += amount;
        entityStaked[entity] += amount;
        globalStaked += amount;

        _syncEntityRate(entity);

        emit Staked(msg.sender, entity, amount);
    }

    function withdraw(address entity, uint256 amount) external nonReentrant {
        require(entity != address(0), "invalid entity");
        require(amount > 0, "amount = 0");
        require(actorStaked[msg.sender][entity] >= amount, "insufficient stake");

        _syncActorState(msg.sender, entity);

        actorStaked[msg.sender][entity] -= amount;
        entityStaked[entity] -= amount;
        globalStaked -= amount;

        _syncEntityRate(entity);

        require(STAKING_TOKEN.transfer(msg.sender, amount), "staking token transfer failed");

        emit Withdrawn(msg.sender, entity, amount);
    }

    function claim(address entity) external nonReentrant {
        require(entity != address(0), "invalid entity");

        uint256 reward = _syncActorState(msg.sender, entity);

        if (reward > 0) {
            actorPaid[msg.sender][entity] += reward;
            require(REWARD_TOKEN.transfer(msg.sender, reward), "reward token transfer failed");
            emit Claimed(msg.sender, entity, reward);
        }
    }

    /* ================= RATES ================= */

    function globalRate() public view returns (uint256) {
        if (globalStaked == 0) return 0;
        return (RewardAccumulator.GLOBAL_EMISSION_RATE * RewardAccumulator.PRECISION) / globalStaked;
    }

    function entityRate(address entity) public view returns (uint256) {
        if (entityStaked[entity] == 0) return 0;
        return (RewardAccumulator.ENTITY_EMISSION_RATE * RewardAccumulator.PRECISION) / entityStaked[entity];
    }

    /* ================= VIEW FUNCTIONS ================= */

    function earned(address actor, address entity) external view returns (uint256) {
        RewardAccumulator.Global storage g = global;
        RewardAccumulator.Entity storage e = entities[entity];
        RewardAccumulator.Actor storage a = actors[actor][entity];

        return a.previewActor(actorStaked[actor][entity], e.previewEntity(g.previewGlobal())) - actorPaid[actor][entity];
    }

    /* ================= INTERNAL ================= */

    function _syncGlobalState() internal {
        global.updateGlobalState();
    }

    function _syncGlobalRate() internal {
        global.updateGlobalRate(globalRate());
    }

    function _syncEntityState(address entity) internal {
        _syncGlobalState();

        entities[entity].updateEntityState(global);
    }

    function _syncEntityRate(address entity) internal {
        _syncGlobalRate();

        entities[entity].updateEntityRate(entityRate(entity));
    }

    function _syncActorState(address actor, address entity) internal returns (uint256) {
        _syncEntityState(entity);

        return actors[actor][entity].updateActorState(
            entities[entity], actorStaked[actor][entity], actorPaid[actor][entity]
        );
    }
}
