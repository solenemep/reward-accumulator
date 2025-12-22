// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "lib/forge-std/src/Test.sol";

import {RewardAccumulator} from "src/libraries/RewardAccumulator.sol";

contract RewardAccumulatorTest is Test {
    using RewardAccumulator for RewardAccumulator.Global;
    using RewardAccumulator for RewardAccumulator.Entity;
    using RewardAccumulator for RewardAccumulator.Actor;

    RewardAccumulator.Global public global;
    RewardAccumulator.Entity public entity;
    RewardAccumulator.Actor public actor;

    uint256 public timeElapsed = 100;

    uint256 public initGlobalRate = 2e18;
    uint256 public globalRate = 1e18;

    uint256 public initEntityRate = 2e17;
    uint256 public entityRate = 5e17;

    uint256 public stakeAmount = 100e18;
    uint256 public paidRewards = 5e16;

    function setUp() public {}

    /* ================= GLOBAL ================= */

    function test_globalInitState() public view {
        assertEq(global.accumulator, 0);
        assertEq(global.lastRate, 0);
        assertEq(global.lastUpdate, 0);
    }

    function test_updateGlobalState_noTimeElapsed() public {
        _setUpGlobal();

        uint256 accumulatorBefore = global.accumulator;
        global.updateGlobalState();

        assertEq(global.accumulator, accumulatorBefore);
        assertEq(global.lastRate, initGlobalRate);
        assertEq(global.lastUpdate, block.timestamp);
    }

    function test_updateGlobalState_withTimeElapsed() public {
        _setUpGlobal();

        skip(timeElapsed);
        uint256 accumulatorBefore = global.accumulator;
        global.updateGlobalState();

        assertEq(global.accumulator, accumulatorBefore + (initGlobalRate * timeElapsed));
        assertEq(global.lastRate, initGlobalRate);
        assertEq(global.lastUpdate, block.timestamp);
    }

    function test_updateGlobalRate_noTimeElapsed() public {
        _setUpGlobal();

        uint256 accumulatorBefore = global.accumulator;
        global.updateGlobalRate(globalRate);

        assertEq(global.accumulator, accumulatorBefore);
        assertEq(global.lastRate, globalRate);
        assertEq(global.lastUpdate, block.timestamp);
    }

    function test_updateGlobalRate_withTimeElapsed() public {
        _setUpGlobal();

        skip(timeElapsed);
        uint256 accumulatorBefore = global.accumulator;
        global.updateGlobalRate(globalRate);

        assertEq(global.accumulator, accumulatorBefore);
        assertEq(global.lastRate, globalRate);
        assertEq(global.lastUpdate, block.timestamp - timeElapsed);
    }

    function test_previewGlobal_noTimeElapsed() public {
        _setUpGlobal();

        uint256 preview = global.previewGlobal();
        uint256 expected = global.accumulator;
        assertEq(preview, expected);
    }

    function test_previewGlobal_withTimeElapsed() public {
        _setUpGlobal();

        skip(timeElapsed);

        uint256 preview = global.previewGlobal();
        uint256 expected = global.accumulator + (global.lastRate * timeElapsed);
        assertEq(preview, expected);
    }

    /* ================= ENTITY ================= */

    function test_entityInitState() public view {
        assertEq(entity.accumulator, 0);
        assertEq(entity.checkpoint, 0);
        assertEq(entity.lastRate, 0);
    }

    function test_updateEntityState_noTimeElapsed() public {
        _setUpEntity();

        uint256 accumulatorBefore = entity.accumulator;
        global.updateGlobalState();
        entity.updateEntityState(global);

        assertEq(entity.accumulator, accumulatorBefore);
        assertEq(entity.checkpoint, global.accumulator);
        assertEq(entity.lastRate, initEntityRate);
    }

    function test_updateEntityState_withTimeElapsed() public {
        _setUpEntity();

        skip(timeElapsed);
        uint256 accumulatorBefore = entity.accumulator;
        uint256 checkpointBefore = entity.checkpoint;
        global.updateGlobalState();
        entity.updateEntityState(global);

        assertEq(
            entity.accumulator,
            accumulatorBefore + initEntityRate * (global.accumulator - checkpointBefore) / RewardAccumulator.PRECISION
        );
        assertEq(entity.checkpoint, global.accumulator);
        assertEq(entity.lastRate, initEntityRate);
    }

    function test_updateEntityRate_noTimeElapsed() public {
        _setUpEntity();

        uint256 accumulatorBefore = entity.accumulator;
        entity.updateEntityRate(entityRate);

        assertEq(entity.accumulator, accumulatorBefore);
        assertEq(entity.checkpoint, global.accumulator);
        assertEq(entity.lastRate, entityRate);
    }

    function test_updateEntityRate_withTimeElapsed() public {
        _setUpEntity();

        skip(timeElapsed);
        uint256 accumulatorBefore = entity.accumulator;
        entity.updateEntityRate(entityRate);

        assertEq(entity.accumulator, accumulatorBefore);
        assertEq(entity.checkpoint, global.accumulator);
        assertEq(entity.lastRate, entityRate);
    }

    function test_previewEntity_noTimeElapsed() public {
        _setUpEntity();

        uint256 preview = entity.previewEntity(global.accumulator);
        uint256 expected = entity.accumulator;
        assertEq(preview, expected);
    }

    function test_previewEntity_withTimeElapsed() public {
        _setUpEntity();

        skip(timeElapsed);

        uint256 preview = entity.previewEntity(global.accumulator);
        uint256 expected = entity.accumulator
            + entity.lastRate * (global.accumulator - entity.checkpoint) / RewardAccumulator.PRECISION;
        assertEq(preview, expected);
    }

    /* ================= ACTOR ================= */

    function test_actorInitState() public view {
        assertEq(actor.accumulator, 0);
        assertEq(actor.checkpoint, 0);
    }

    function test_updateActorState_noTimeElapsed_noStakeChange_noPaidRewards() public {
        _setUpActor();

        uint256 accumulatorBefore = actor.accumulator;
        global.updateGlobalState();
        entity.updateEntityState(global);
        uint256 reward = actor.updateActorState(entity, 0, 0);

        assertEq(actor.accumulator, accumulatorBefore);
        assertEq(actor.checkpoint, entity.accumulator);
        assertEq(reward, 0);
    }

    function test_updateActorState_noTimeElapsed_withStakeChange_noPaidRewards() public {
        _setUpActor();

        uint256 accumulatorBefore = actor.accumulator;
        global.updateGlobalState();
        entity.updateEntityState(global);
        uint256 reward = actor.updateActorState(entity, stakeAmount, 0);

        assertEq(actor.accumulator, accumulatorBefore);
        assertEq(actor.checkpoint, entity.accumulator);
        assertEq(reward, 0);
    }

    function test_updateActorState_noTimeElapsed_withStakeChange_withPaidRewards() public {
        _setUpActor();

        uint256 accumulatorBefore = actor.accumulator;
        global.updateGlobalState();
        entity.updateEntityState(global);
        uint256 reward = actor.updateActorState(entity, stakeAmount, paidRewards);

        assertEq(actor.accumulator, accumulatorBefore);
        assertEq(actor.checkpoint, entity.accumulator);
        assertEq(reward, 0);
    }

    function test_updateActorState_withTimeElapsed_noStakeChange_noPaidRewards() public {
        _setUpActor();

        skip(timeElapsed);
        uint256 accumulatorBefore = actor.accumulator;
        global.updateGlobalState();
        entity.updateEntityState(global);
        uint256 reward = actor.updateActorState(entity, 0, 0);

        assertEq(actor.accumulator, accumulatorBefore);
        assertEq(actor.checkpoint, entity.accumulator);
        assertEq(reward, 0);
    }

    function test_updateActorState_withTimeElapsed_withStakeChange_noPaidRewards() public {
        _setUpActor();

        skip(timeElapsed);
        uint256 accumulatorBefore = actor.accumulator;
        uint256 checkpointBefore = actor.checkpoint;
        global.updateGlobalState();
        entity.updateEntityState(global);
        uint256 reward = actor.updateActorState(entity, stakeAmount, 0);

        assertEq(
            actor.accumulator,
            accumulatorBefore + stakeAmount * (entity.accumulator - checkpointBefore) / RewardAccumulator.PRECISION
        );
        assertEq(actor.checkpoint, entity.accumulator);
        assertEq(reward, actor.accumulator);
        assertTrue(reward > 0);
    }

    function test_updateActorState_withTimeElapsed_withStakeChange_withPaidRewards() public {
        _setUpActor();

        skip(timeElapsed);
        uint256 accumulatorBefore = actor.accumulator;
        uint256 checkpointBefore = actor.checkpoint;
        global.updateGlobalState();
        entity.updateEntityState(global);
        uint256 reward = actor.updateActorState(entity, stakeAmount, paidRewards);

        assertEq(
            actor.accumulator,
            accumulatorBefore + stakeAmount * (entity.accumulator - checkpointBefore) / RewardAccumulator.PRECISION
        );
        assertEq(actor.checkpoint, entity.accumulator);
        assertEq(reward, actor.accumulator - paidRewards);
        assertTrue(reward > 0);
    }

    function test_previewActor_noTimeElapsed_noStakeChange_noPaidRewards() public {
        _setUpActor();

        uint256 preview = actor.previewActor(0, entity.previewEntity(global.accumulator));
        uint256 expected = actor.accumulator;
        assertEq(preview, expected);
    }

    function test_previewActor_noTimeElapsed_withStakeChange_noPaidRewards() public {
        _setUpActor();

        uint256 preview = actor.previewActor(stakeAmount, entity.previewEntity(global.accumulator));
        uint256 expected = actor.accumulator;
        assertEq(preview, expected);
    }

    function test_previewActor_noTimeElapsed_withStakeChange_withPaidRewards() public {
        _setUpActor();

        uint256 preview = actor.previewActor(stakeAmount, entity.previewEntity(global.accumulator));
        uint256 expected = actor.accumulator;
        assertEq(preview, expected);
    }

    function test_previewActor_withTimeElapsed_noStakeChange_noPaidRewards() public {
        _setUpActor();

        skip(timeElapsed);

        uint256 preview = actor.previewActor(0, entity.previewEntity(global.accumulator));
        uint256 expected = actor.accumulator;
        assertEq(preview, expected);
    }

    function test_previewActor_withTimeElapsed_withStakeChange_noPaidRewards() public {
        _setUpActor();

        skip(timeElapsed);

        uint256 preview = actor.previewActor(stakeAmount, entity.previewEntity(global.accumulator));
        uint256 expected =
            actor.accumulator + stakeAmount * (entity.accumulator - actor.checkpoint) / RewardAccumulator.PRECISION;
        assertEq(preview, expected);
    }

    function test_previewActor_withTimeElapsed_withStakeChange_withPaidRewards() public {
        _setUpActor();

        skip(timeElapsed);

        uint256 preview = actor.previewActor(stakeAmount, entity.previewEntity(global.accumulator));
        uint256 expected =
            actor.accumulator + stakeAmount * (entity.accumulator - actor.checkpoint) / RewardAccumulator.PRECISION;
        assertEq(preview, expected);
    }

    /* ================= INTERNAL ================= */

    function _setUpGlobal() internal {
        skip(timeElapsed);
        global.updateGlobalState();
        global.updateGlobalRate(initGlobalRate);
    }

    function _setUpEntity() internal {
        _setUpGlobal();
        entity.updateEntityState(global);
        entity.updateEntityRate(initEntityRate);
    }

    function _setUpActor() internal {
        _setUpEntity();
        actor.updateActorState(entity, stakeAmount, paidRewards);
    }
}
