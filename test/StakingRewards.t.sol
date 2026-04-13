// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "lib/forge-std/src/Test.sol";

import {StakingRewards} from "src/StakingRewards.sol";
import {MockERC20} from "test/mocks/MockERC20.sol";

contract StakingRewardsTest is Test {
    uint256 public constant INITIAL_BALANCE = 1000e18;
    uint256 public constant PRECISION = 1e18;
    uint256 public constant GLOBAL_EMISSION_RATE = 1e17;
    uint256 public constant ENTITY_EMISSION_RATE = 1e17;
    uint256 public constant MAX_ABS_DELTA = 1e5;

    struct Balances {
        uint256 stakingContract;
        uint256 stakingAlice;
        uint256 stakingBob;
        uint256 stakingCarol;
        uint256 rewardContract;
        uint256 rewardAlice;
        uint256 rewardBob;
        uint256 rewardCarol;
    }

    MockERC20 public stakingToken;
    MockERC20 public rewardToken;

    StakingRewards public stakingRewards;

    address public entity1 = makeAddr("entity1");
    address public entity2 = makeAddr("entity2");

    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");
    address public carol = makeAddr("carol");

    uint256 public stakeAmount1 = 100e18;
    uint256 public stakeAmount2 = 200e18;
    uint256 public stakeAmount3 = 300e18;

    uint256 public timeElapsed = 100;

    function setUp() public {
        stakingToken = new MockERC20("Staking Token", "STK");
        rewardToken = new MockERC20("Reward Token", "RWD");

        stakingRewards = new StakingRewards(address(stakingToken), address(rewardToken));

        stakingToken.mint(alice, INITIAL_BALANCE);
        stakingToken.mint(bob, INITIAL_BALANCE);
        stakingToken.mint(carol, INITIAL_BALANCE);

        rewardToken.mint(address(stakingRewards), 1000000e18);

        vm.prank(alice);
        stakingToken.approve(address(stakingRewards), type(uint256).max);
        vm.prank(bob);
        stakingToken.approve(address(stakingRewards), type(uint256).max);
        vm.prank(carol);
        stakingToken.approve(address(stakingRewards), type(uint256).max);
    }

    function test_contractInitState() public view {
        assertEq(address(stakingRewards.STAKING_TOKEN()), address(stakingToken));
        assertEq(address(stakingRewards.REWARD_TOKEN()), address(rewardToken));
        assertEq(stakingRewards.globalStaked(), 0);

        Balances memory before = _snapshot();
        assertEq(before.stakingContract, 0);
        assertEq(before.stakingAlice, INITIAL_BALANCE);
        assertEq(before.stakingBob, INITIAL_BALANCE);
        assertEq(before.stakingCarol, INITIAL_BALANCE);
    }

    /* ================= USER ACTIONS ================= */

    function test_stake_pass_oneUser_oneEntity() public {
        Balances memory before = _snapshot();

        vm.prank(alice);
        stakingRewards.stake(entity1, stakeAmount1);

        assertEq(stakingRewards.actorStaked(alice, entity1), stakeAmount1);
        assertEq(stakingRewards.actorStaked(bob, entity1), 0);
        assertEq(stakingRewards.actorStaked(carol, entity1), 0);

        assertEq(stakingRewards.actorStaked(alice, entity2), 0);
        assertEq(stakingRewards.actorStaked(bob, entity2), 0);
        assertEq(stakingRewards.actorStaked(carol, entity2), 0);

        assertEq(stakingRewards.entityStaked(entity1), stakeAmount1);
        assertEq(stakingRewards.entityStaked(entity2), 0);

        assertEq(stakingRewards.globalStaked(), stakeAmount1);

        assertEq(stakingToken.balanceOf(address(stakingRewards)), before.stakingContract + stakeAmount1);
        assertEq(stakingToken.balanceOf(alice), before.stakingAlice - stakeAmount1);
        assertEq(stakingToken.balanceOf(bob), before.stakingBob);
        assertEq(stakingToken.balanceOf(carol), before.stakingCarol);

        assertEq(rewardToken.balanceOf(address(stakingRewards)), before.rewardContract);
        assertEq(rewardToken.balanceOf(alice), before.rewardAlice);
        assertEq(rewardToken.balanceOf(bob), before.rewardBob);
        assertEq(rewardToken.balanceOf(carol), before.rewardCarol);
    }

    function test_stake_pass_oneUser_multipleEntities() public {
        Balances memory before = _snapshot();

        vm.prank(alice);
        stakingRewards.stake(entity1, stakeAmount1);

        vm.prank(alice);
        stakingRewards.stake(entity2, stakeAmount2);

        assertEq(stakingRewards.actorStaked(alice, entity1), stakeAmount1);
        assertEq(stakingRewards.actorStaked(bob, entity1), 0);
        assertEq(stakingRewards.actorStaked(carol, entity1), 0);

        assertEq(stakingRewards.actorStaked(alice, entity2), stakeAmount2);
        assertEq(stakingRewards.actorStaked(bob, entity2), 0);
        assertEq(stakingRewards.actorStaked(carol, entity2), 0);

        assertEq(stakingRewards.entityStaked(entity1), stakeAmount1);
        assertEq(stakingRewards.entityStaked(entity2), stakeAmount2);

        assertEq(stakingRewards.globalStaked(), stakeAmount1 + stakeAmount2);

        assertEq(stakingToken.balanceOf(address(stakingRewards)), before.stakingContract + stakeAmount1 + stakeAmount2);
        assertEq(stakingToken.balanceOf(alice), before.stakingAlice - stakeAmount1 - stakeAmount2);
        assertEq(stakingToken.balanceOf(bob), before.stakingBob);
        assertEq(stakingToken.balanceOf(carol), before.stakingCarol);

        assertEq(rewardToken.balanceOf(address(stakingRewards)), before.rewardContract);
        assertEq(rewardToken.balanceOf(alice), before.rewardAlice);
        assertEq(rewardToken.balanceOf(bob), before.rewardBob);
        assertEq(rewardToken.balanceOf(carol), before.rewardCarol);
    }

    function test_stake_pass_multipleUsers_oneEntity() public {
        Balances memory before = _snapshot();

        vm.prank(alice);
        stakingRewards.stake(entity1, stakeAmount1);

        vm.prank(bob);
        stakingRewards.stake(entity1, stakeAmount2);

        assertEq(stakingRewards.actorStaked(alice, entity1), stakeAmount1);
        assertEq(stakingRewards.actorStaked(bob, entity1), stakeAmount2);
        assertEq(stakingRewards.actorStaked(carol, entity1), 0);

        assertEq(stakingRewards.actorStaked(alice, entity2), 0);
        assertEq(stakingRewards.actorStaked(bob, entity2), 0);
        assertEq(stakingRewards.actorStaked(carol, entity2), 0);

        assertEq(stakingRewards.entityStaked(entity1), stakeAmount1 + stakeAmount2);
        assertEq(stakingRewards.entityStaked(entity2), 0);

        assertEq(stakingRewards.globalStaked(), stakeAmount1 + stakeAmount2);

        assertEq(stakingToken.balanceOf(address(stakingRewards)), before.stakingContract + stakeAmount1 + stakeAmount2);
        assertEq(stakingToken.balanceOf(alice), before.stakingAlice - stakeAmount1);
        assertEq(stakingToken.balanceOf(bob), before.stakingBob - stakeAmount2);
        assertEq(stakingToken.balanceOf(carol), before.stakingCarol);

        assertEq(rewardToken.balanceOf(address(stakingRewards)), before.rewardContract);
        assertEq(rewardToken.balanceOf(alice), before.rewardAlice);
        assertEq(rewardToken.balanceOf(bob), before.rewardBob);
        assertEq(rewardToken.balanceOf(carol), before.rewardCarol);
    }

    function test_stake_pass_multipleUsers_multipleEntities() public {
        Balances memory before = _snapshot();

        vm.prank(alice);
        stakingRewards.stake(entity1, stakeAmount1);

        vm.prank(bob);
        stakingRewards.stake(entity1, stakeAmount2);

        vm.prank(carol);
        stakingRewards.stake(entity2, stakeAmount3);

        assertEq(stakingRewards.actorStaked(alice, entity1), stakeAmount1);
        assertEq(stakingRewards.actorStaked(bob, entity1), stakeAmount2);
        assertEq(stakingRewards.actorStaked(carol, entity1), 0);

        assertEq(stakingRewards.actorStaked(alice, entity2), 0);
        assertEq(stakingRewards.actorStaked(bob, entity2), 0);
        assertEq(stakingRewards.actorStaked(carol, entity2), stakeAmount3);

        assertEq(stakingRewards.entityStaked(entity1), stakeAmount1 + stakeAmount2);
        assertEq(stakingRewards.entityStaked(entity2), stakeAmount3);

        assertEq(stakingRewards.globalStaked(), stakeAmount1 + stakeAmount2 + stakeAmount3);

        assertEq(
            stakingToken.balanceOf(address(stakingRewards)),
            before.stakingContract + stakeAmount1 + stakeAmount2 + stakeAmount3
        );
        assertEq(stakingToken.balanceOf(alice), before.stakingAlice - stakeAmount1);
        assertEq(stakingToken.balanceOf(bob), before.stakingBob - stakeAmount2);
        assertEq(stakingToken.balanceOf(carol), before.stakingCarol - stakeAmount3);

        assertEq(rewardToken.balanceOf(address(stakingRewards)), before.rewardContract);
        assertEq(rewardToken.balanceOf(alice), before.rewardAlice);
        assertEq(rewardToken.balanceOf(bob), before.rewardBob);
        assertEq(rewardToken.balanceOf(carol), before.rewardCarol);
    }

    function test_stake_revert_zeroAmount() public {
        vm.expectRevert("amount = 0");
        stakingRewards.stake(entity1, 0);
    }

    function test_withdraw_pass_oneUser_oneEntity() public {
        vm.prank(alice);
        stakingRewards.stake(entity1, stakeAmount1);

        Balances memory before = _snapshot();

        vm.prank(alice);
        stakingRewards.withdraw(entity1, stakeAmount1);

        assertEq(stakingRewards.actorStaked(alice, entity1), 0);
        assertEq(stakingRewards.actorStaked(bob, entity1), 0);
        assertEq(stakingRewards.actorStaked(carol, entity1), 0);

        assertEq(stakingRewards.actorStaked(alice, entity2), 0);
        assertEq(stakingRewards.actorStaked(bob, entity2), 0);
        assertEq(stakingRewards.actorStaked(carol, entity2), 0);

        assertEq(stakingRewards.entityStaked(entity1), 0);
        assertEq(stakingRewards.entityStaked(entity2), 0);

        assertEq(stakingRewards.globalStaked(), 0);

        assertEq(stakingToken.balanceOf(address(stakingRewards)), before.stakingContract - stakeAmount1);
        assertEq(stakingToken.balanceOf(alice), before.stakingAlice + stakeAmount1);
        assertEq(stakingToken.balanceOf(bob), before.stakingBob);
        assertEq(stakingToken.balanceOf(carol), before.stakingCarol);

        assertEq(rewardToken.balanceOf(address(stakingRewards)), before.rewardContract);
        assertEq(rewardToken.balanceOf(alice), before.rewardAlice);
        assertEq(rewardToken.balanceOf(bob), before.rewardBob);
        assertEq(rewardToken.balanceOf(carol), before.rewardCarol);
    }

    function test_withdraw_pass_oneUser_multipleEntities() public {
        vm.prank(alice);
        stakingRewards.stake(entity1, stakeAmount1);

        vm.prank(alice);
        stakingRewards.stake(entity2, stakeAmount2);

        Balances memory before = _snapshot();

        vm.prank(alice);
        stakingRewards.withdraw(entity1, stakeAmount1);

        vm.prank(alice);
        stakingRewards.withdraw(entity2, stakeAmount2);

        assertEq(stakingRewards.actorStaked(alice, entity1), 0);
        assertEq(stakingRewards.actorStaked(bob, entity1), 0);
        assertEq(stakingRewards.actorStaked(carol, entity1), 0);

        assertEq(stakingRewards.actorStaked(alice, entity2), 0);
        assertEq(stakingRewards.actorStaked(bob, entity2), 0);
        assertEq(stakingRewards.actorStaked(carol, entity2), 0);

        assertEq(stakingRewards.entityStaked(entity1), 0);
        assertEq(stakingRewards.entityStaked(entity2), 0);

        assertEq(stakingRewards.globalStaked(), 0);

        assertEq(stakingToken.balanceOf(address(stakingRewards)), before.stakingContract - stakeAmount1 - stakeAmount2);
        assertEq(stakingToken.balanceOf(alice), before.stakingAlice + stakeAmount1 + stakeAmount2);
        assertEq(stakingToken.balanceOf(bob), before.stakingBob);
        assertEq(stakingToken.balanceOf(carol), before.stakingCarol);

        assertEq(rewardToken.balanceOf(address(stakingRewards)), before.rewardContract);
        assertEq(rewardToken.balanceOf(alice), before.rewardAlice);
        assertEq(rewardToken.balanceOf(bob), before.rewardBob);
        assertEq(rewardToken.balanceOf(carol), before.rewardCarol);
    }

    function test_withdraw_pass_multipleUsers_oneEntity() public {
        vm.prank(alice);
        stakingRewards.stake(entity1, stakeAmount1);

        vm.prank(bob);
        stakingRewards.stake(entity1, stakeAmount2);

        Balances memory before = _snapshot();

        vm.prank(alice);
        stakingRewards.withdraw(entity1, stakeAmount1);

        vm.prank(bob);
        stakingRewards.withdraw(entity1, stakeAmount2);

        assertEq(stakingRewards.actorStaked(alice, entity1), 0);
        assertEq(stakingRewards.actorStaked(bob, entity1), 0);
        assertEq(stakingRewards.actorStaked(carol, entity1), 0);

        assertEq(stakingRewards.actorStaked(alice, entity2), 0);
        assertEq(stakingRewards.actorStaked(bob, entity2), 0);
        assertEq(stakingRewards.actorStaked(carol, entity2), 0);

        assertEq(stakingRewards.entityStaked(entity1), 0);
        assertEq(stakingRewards.entityStaked(entity2), 0);

        assertEq(stakingRewards.globalStaked(), 0);

        assertEq(stakingToken.balanceOf(address(stakingRewards)), before.stakingContract - stakeAmount1 - stakeAmount2);
        assertEq(stakingToken.balanceOf(alice), before.stakingAlice + stakeAmount1);
        assertEq(stakingToken.balanceOf(bob), before.stakingBob + stakeAmount2);
        assertEq(stakingToken.balanceOf(carol), before.stakingCarol);

        assertEq(rewardToken.balanceOf(address(stakingRewards)), before.rewardContract);
        assertEq(rewardToken.balanceOf(alice), before.rewardAlice);
        assertEq(rewardToken.balanceOf(bob), before.rewardBob);
        assertEq(rewardToken.balanceOf(carol), before.rewardCarol);
    }

    function test_withdraw_pass_multipleUsers_multipleEntities() public {
        vm.prank(alice);
        stakingRewards.stake(entity1, stakeAmount1);

        vm.prank(bob);
        stakingRewards.stake(entity1, stakeAmount2);

        vm.prank(carol);
        stakingRewards.stake(entity2, stakeAmount3);

        Balances memory before = _snapshot();

        vm.prank(alice);
        stakingRewards.withdraw(entity1, stakeAmount1);

        vm.prank(bob);
        stakingRewards.withdraw(entity1, stakeAmount2);

        vm.prank(carol);
        stakingRewards.withdraw(entity2, stakeAmount3);

        assertEq(stakingRewards.actorStaked(alice, entity1), 0);
        assertEq(stakingRewards.actorStaked(bob, entity1), 0);
        assertEq(stakingRewards.actorStaked(carol, entity1), 0);

        assertEq(stakingRewards.actorStaked(alice, entity2), 0);
        assertEq(stakingRewards.actorStaked(bob, entity2), 0);
        assertEq(stakingRewards.actorStaked(carol, entity2), 0);

        assertEq(stakingRewards.entityStaked(entity1), 0);
        assertEq(stakingRewards.entityStaked(entity2), 0);

        assertEq(stakingRewards.globalStaked(), 0);

        assertEq(
            stakingToken.balanceOf(address(stakingRewards)),
            before.stakingContract - stakeAmount1 - stakeAmount2 - stakeAmount3
        );
        assertEq(stakingToken.balanceOf(alice), before.stakingAlice + stakeAmount1);
        assertEq(stakingToken.balanceOf(bob), before.stakingBob + stakeAmount2);
        assertEq(stakingToken.balanceOf(carol), before.stakingCarol + stakeAmount3);

        assertEq(rewardToken.balanceOf(address(stakingRewards)), before.rewardContract);
        assertEq(rewardToken.balanceOf(alice), before.rewardAlice);
        assertEq(rewardToken.balanceOf(bob), before.rewardBob);
        assertEq(rewardToken.balanceOf(carol), before.rewardCarol);
    }

    function test_withdraw_revert_zeroAmount() public {
        vm.prank(alice);
        stakingRewards.stake(entity1, stakeAmount1);

        vm.expectRevert("amount = 0");
        vm.prank(alice);
        stakingRewards.withdraw(entity1, 0);
    }

    function test_withdraw_revert_insufficientStake() public {
        vm.prank(alice);
        stakingRewards.stake(entity1, stakeAmount1);

        vm.expectRevert("insufficient stake");
        vm.prank(alice);
        stakingRewards.withdraw(entity1, stakeAmount1 + 1);
    }

    function test_claim_pass_oneUser_oneEntity() public {
        vm.prank(alice);
        stakingRewards.stake(entity1, stakeAmount1);

        skip(timeElapsed);

        Balances memory before = _snapshot();
        uint256 earnedRewards1 = stakingRewards.earned(alice, entity1);
        assertTrue(earnedRewards1 > 0);

        vm.prank(alice);
        stakingRewards.claim(entity1);

        assertEq(stakingRewards.actorStaked(alice, entity1), stakeAmount1);
        assertEq(stakingRewards.actorStaked(bob, entity1), 0);
        assertEq(stakingRewards.actorStaked(carol, entity1), 0);

        assertEq(stakingRewards.actorStaked(alice, entity2), 0);
        assertEq(stakingRewards.actorStaked(bob, entity2), 0);
        assertEq(stakingRewards.actorStaked(carol, entity2), 0);

        assertEq(stakingRewards.entityStaked(entity1), stakeAmount1);
        assertEq(stakingRewards.entityStaked(entity2), 0);

        assertEq(stakingRewards.globalStaked(), stakeAmount1);

        assertEq(stakingToken.balanceOf(address(stakingRewards)), before.stakingContract);
        assertEq(stakingToken.balanceOf(alice), before.stakingAlice);
        assertEq(stakingToken.balanceOf(bob), before.stakingBob);
        assertEq(stakingToken.balanceOf(carol), before.stakingCarol);

        assertEq(rewardToken.balanceOf(address(stakingRewards)), before.rewardContract - earnedRewards1);
        assertEq(rewardToken.balanceOf(alice), before.rewardAlice + earnedRewards1);
        assertEq(rewardToken.balanceOf(bob), before.rewardBob);
        assertEq(rewardToken.balanceOf(carol), before.rewardCarol);
    }

    function test_claim_pass_oneUser_multipleEntities() public {
        vm.prank(alice);
        stakingRewards.stake(entity1, stakeAmount1);

        vm.prank(alice);
        stakingRewards.stake(entity2, stakeAmount2);

        skip(timeElapsed);

        Balances memory before = _snapshot();
        uint256 earnedRewards1 = stakingRewards.earned(alice, entity1);
        assertTrue(earnedRewards1 > 0);
        uint256 earnedRewards2 = stakingRewards.earned(alice, entity2);
        assertTrue(earnedRewards2 > 0);

        vm.prank(alice);
        stakingRewards.claim(entity1);

        vm.prank(alice);
        stakingRewards.claim(entity2);

        assertEq(stakingRewards.actorStaked(alice, entity1), stakeAmount1);
        assertEq(stakingRewards.actorStaked(bob, entity1), 0);
        assertEq(stakingRewards.actorStaked(carol, entity1), 0);

        assertEq(stakingRewards.actorStaked(alice, entity2), stakeAmount2);
        assertEq(stakingRewards.actorStaked(bob, entity2), 0);
        assertEq(stakingRewards.actorStaked(carol, entity2), 0);

        assertEq(stakingRewards.entityStaked(entity1), stakeAmount1);
        assertEq(stakingRewards.entityStaked(entity2), stakeAmount2);

        assertEq(stakingRewards.globalStaked(), stakeAmount1 + stakeAmount2);

        assertEq(stakingToken.balanceOf(address(stakingRewards)), before.stakingContract);
        assertEq(stakingToken.balanceOf(alice), before.stakingAlice);
        assertEq(stakingToken.balanceOf(bob), before.stakingBob);
        assertEq(stakingToken.balanceOf(carol), before.stakingCarol);

        assertEq(
            rewardToken.balanceOf(address(stakingRewards)), before.rewardContract - earnedRewards1 - earnedRewards2
        );
        assertEq(rewardToken.balanceOf(alice), before.rewardAlice + earnedRewards1 + earnedRewards2);
        assertEq(rewardToken.balanceOf(bob), before.rewardBob);
        assertEq(rewardToken.balanceOf(carol), before.rewardCarol);
    }

    function test_claim_pass_multipleUsers_oneEntity() public {
        vm.prank(alice);
        stakingRewards.stake(entity1, stakeAmount1);

        vm.prank(bob);
        stakingRewards.stake(entity1, stakeAmount2);

        skip(timeElapsed);

        Balances memory before = _snapshot();
        uint256 earnedRewards1 = stakingRewards.earned(alice, entity1);
        assertTrue(earnedRewards1 > 0);
        uint256 earnedRewards2 = stakingRewards.earned(bob, entity1);
        assertTrue(earnedRewards2 > 0);

        vm.prank(alice);
        stakingRewards.claim(entity1);

        vm.prank(bob);
        stakingRewards.claim(entity1);

        assertEq(stakingRewards.actorStaked(alice, entity1), stakeAmount1);
        assertEq(stakingRewards.actorStaked(bob, entity1), stakeAmount2);
        assertEq(stakingRewards.actorStaked(carol, entity1), 0);

        assertEq(stakingRewards.actorStaked(alice, entity2), 0);
        assertEq(stakingRewards.actorStaked(bob, entity2), 0);
        assertEq(stakingRewards.actorStaked(carol, entity2), 0);

        assertEq(stakingRewards.entityStaked(entity1), stakeAmount1 + stakeAmount2);
        assertEq(stakingRewards.entityStaked(entity2), 0);

        assertEq(stakingRewards.globalStaked(), stakeAmount1 + stakeAmount2);

        assertEq(stakingToken.balanceOf(address(stakingRewards)), before.stakingContract);
        assertEq(stakingToken.balanceOf(alice), before.stakingAlice);
        assertEq(stakingToken.balanceOf(bob), before.stakingBob);
        assertEq(stakingToken.balanceOf(carol), before.stakingCarol);

        assertEq(
            rewardToken.balanceOf(address(stakingRewards)), before.rewardContract - earnedRewards1 - earnedRewards2
        );
        assertEq(rewardToken.balanceOf(alice), before.rewardAlice + earnedRewards1);
        assertEq(rewardToken.balanceOf(bob), before.rewardBob + earnedRewards2);
        assertEq(rewardToken.balanceOf(carol), before.rewardCarol);
    }

    function test_claim_pass_multipleUsers_multipleEntities() public {
        vm.prank(alice);
        stakingRewards.stake(entity1, stakeAmount1);

        vm.prank(bob);
        stakingRewards.stake(entity1, stakeAmount2);

        vm.prank(carol);
        stakingRewards.stake(entity2, stakeAmount3);

        skip(timeElapsed);

        Balances memory before = _snapshot();
        uint256 earnedRewards1 = stakingRewards.earned(alice, entity1);
        assertTrue(earnedRewards1 > 0);
        uint256 earnedRewards2 = stakingRewards.earned(bob, entity1);
        assertTrue(earnedRewards2 > 0);
        uint256 earnedRewards3 = stakingRewards.earned(carol, entity2);
        assertTrue(earnedRewards3 > 0);

        vm.prank(alice);
        stakingRewards.claim(entity1);

        vm.prank(bob);
        stakingRewards.claim(entity1);

        vm.prank(carol);
        stakingRewards.claim(entity2);

        assertEq(stakingRewards.actorStaked(alice, entity1), stakeAmount1);
        assertEq(stakingRewards.actorStaked(bob, entity1), stakeAmount2);
        assertEq(stakingRewards.actorStaked(carol, entity1), 0);

        assertEq(stakingRewards.actorStaked(alice, entity2), 0);
        assertEq(stakingRewards.actorStaked(bob, entity2), 0);
        assertEq(stakingRewards.actorStaked(carol, entity2), stakeAmount3);

        assertEq(stakingRewards.entityStaked(entity1), stakeAmount1 + stakeAmount2);
        assertEq(stakingRewards.entityStaked(entity2), stakeAmount3);

        assertEq(stakingRewards.globalStaked(), stakeAmount1 + stakeAmount2 + stakeAmount3);

        assertEq(stakingToken.balanceOf(address(stakingRewards)), before.stakingContract);
        assertEq(stakingToken.balanceOf(alice), before.stakingAlice);
        assertEq(stakingToken.balanceOf(bob), before.stakingBob);
        assertEq(stakingToken.balanceOf(carol), before.stakingCarol);

        assertEq(
            rewardToken.balanceOf(address(stakingRewards)),
            before.rewardContract - earnedRewards1 - earnedRewards2 - earnedRewards3
        );
        assertEq(rewardToken.balanceOf(alice), before.rewardAlice + earnedRewards1);
        assertEq(rewardToken.balanceOf(bob), before.rewardBob + earnedRewards2);
        assertEq(rewardToken.balanceOf(carol), before.rewardCarol + earnedRewards3);
    }

    /* ================= REWARD CALCULATION ================= */

    function test_earned_oneUser_oneEntity() public {
        vm.prank(alice);
        stakingRewards.stake(entity1, stakeAmount1);

        skip(timeElapsed);

        uint256 earnedRewards1 = stakingRewards.earned(alice, entity1);
        assertEq(earnedRewards1, _getEarnedExpected(stakeAmount1, stakeAmount1, stakeAmount1));
    }

    function test_earned_pass_oneUser_multipleEntities() public {
        vm.prank(alice);
        stakingRewards.stake(entity1, stakeAmount1);

        vm.prank(alice);
        stakingRewards.stake(entity2, stakeAmount2);

        skip(timeElapsed);

        uint256 earnedRewards1 = stakingRewards.earned(alice, entity1);
        assertApproxEqAbs(
            earnedRewards1, _getEarnedExpected(stakeAmount1, stakeAmount1, stakeAmount1 + stakeAmount2), MAX_ABS_DELTA
        );
        uint256 earnedRewards2 = stakingRewards.earned(alice, entity2);
        assertApproxEqAbs(
            earnedRewards2, _getEarnedExpected(stakeAmount2, stakeAmount2, stakeAmount1 + stakeAmount2), MAX_ABS_DELTA
        );
    }

    function test_earned_multipleUsers_oneEntity() public {
        vm.prank(alice);
        stakingRewards.stake(entity1, stakeAmount1);

        vm.prank(bob);
        stakingRewards.stake(entity1, stakeAmount2);

        skip(timeElapsed);

        uint256 earnedRewards1 = stakingRewards.earned(alice, entity1);
        assertApproxEqAbs(
            earnedRewards1,
            _getEarnedExpected(stakeAmount1, stakeAmount1 + stakeAmount2, stakeAmount1 + stakeAmount2),
            MAX_ABS_DELTA
        );
        uint256 earnedRewards2 = stakingRewards.earned(bob, entity1);
        assertApproxEqAbs(
            earnedRewards2,
            _getEarnedExpected(stakeAmount2, stakeAmount1 + stakeAmount2, stakeAmount1 + stakeAmount2),
            MAX_ABS_DELTA
        );
    }

    function test_earned_multipleUsers_multipleEntities() public {
        vm.prank(alice);
        stakingRewards.stake(entity1, stakeAmount1);

        vm.prank(bob);
        stakingRewards.stake(entity1, stakeAmount2);

        vm.prank(carol);
        stakingRewards.stake(entity2, stakeAmount3);

        skip(timeElapsed);

        uint256 earnedRewards1 = stakingRewards.earned(alice, entity1);
        assertApproxEqAbs(
            earnedRewards1,
            _getEarnedExpected(stakeAmount1, stakeAmount1 + stakeAmount2, stakeAmount1 + stakeAmount2 + stakeAmount3),
            MAX_ABS_DELTA
        );
        uint256 earnedRewards2 = stakingRewards.earned(bob, entity1);
        assertApproxEqAbs(
            earnedRewards2,
            _getEarnedExpected(stakeAmount2, stakeAmount1 + stakeAmount2, stakeAmount1 + stakeAmount2 + stakeAmount3),
            MAX_ABS_DELTA
        );
        uint256 earnedRewards3 = stakingRewards.earned(carol, entity2);
        assertApproxEqAbs(
            earnedRewards3,
            _getEarnedExpected(stakeAmount3, stakeAmount3, stakeAmount1 + stakeAmount2 + stakeAmount3),
            MAX_ABS_DELTA
        );
    }

    /* ================= RATES ================= */

    function test_globalRate_noStake() public view {
        uint256 globalRate = stakingRewards.globalRate();
        assertEq(globalRate, 0);
    }

    function test_globalRate_withStake() public {
        vm.prank(alice);
        stakingRewards.stake(entity1, stakeAmount1);

        uint256 globalRate = stakingRewards.globalRate();
        assertEq(globalRate, (GLOBAL_EMISSION_RATE * PRECISION) / stakeAmount1);
    }

    function test_entityRate_noStake() public view {
        uint256 entityRate1 = stakingRewards.entityRate(entity1);
        assertEq(entityRate1, 0);

        uint256 entityRate2 = stakingRewards.entityRate(entity2);
        assertEq(entityRate2, 0);
    }

    function test_entityRate_withStake() public {
        vm.prank(alice);
        stakingRewards.stake(entity1, stakeAmount1);

        vm.prank(bob);
        stakingRewards.stake(entity2, stakeAmount2);

        vm.prank(carol);
        stakingRewards.stake(entity2, stakeAmount3);

        uint256 entityRate1 = stakingRewards.entityRate(entity1);
        assertEq(entityRate1, ENTITY_EMISSION_RATE * PRECISION / stakeAmount1);

        uint256 entityRate2 = stakingRewards.entityRate(entity2);
        assertEq(entityRate2, ENTITY_EMISSION_RATE * PRECISION / (stakeAmount2 + stakeAmount3));
    }

    /* ================= INTERNAL ================= */

    function _snapshot() internal view returns (Balances memory) {
        return Balances({
            stakingContract: stakingToken.balanceOf(address(stakingRewards)),
            stakingAlice: stakingToken.balanceOf(alice),
            stakingBob: stakingToken.balanceOf(bob),
            stakingCarol: stakingToken.balanceOf(carol),
            rewardContract: rewardToken.balanceOf(address(stakingRewards)),
            rewardAlice: rewardToken.balanceOf(alice),
            rewardBob: rewardToken.balanceOf(bob),
            rewardCarol: rewardToken.balanceOf(carol)
        });
    }

    function _getEarnedExpected(uint256 actorStake, uint256 entityStaked, uint256 globalStaked)
        internal
        view
        returns (uint256)
    {
        return (actorStake * ENTITY_EMISSION_RATE * GLOBAL_EMISSION_RATE * timeElapsed) / (entityStaked * globalStaked);
    }
}
