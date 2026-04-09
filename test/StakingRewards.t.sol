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

    uint256 public stakingContractBalanceBefore;
    uint256 public stakingAliceBalanceBefore;
    uint256 public stakingBobBalanceBefore;
    uint256 public stakingCarolBalanceBefore;

    uint256 public rewardContractBalanceBefore;
    uint256 public rewardAliceBalanceBefore;
    uint256 public rewardBobBalanceBefore;
    uint256 public rewardCarolBalanceBefore;

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

    function test_contractInitState() public {
        assertEq(address(stakingRewards.STAKING_TOKEN()), address(stakingToken));
        assertEq(address(stakingRewards.REWARD_TOKEN()), address(rewardToken));
        assertEq(stakingRewards.globalStaked(), 0);

        _cacheBalancesBefore();
        assertEq(stakingContractBalanceBefore, 0);
        assertEq(stakingAliceBalanceBefore, INITIAL_BALANCE);
        assertEq(stakingBobBalanceBefore, INITIAL_BALANCE);
        assertEq(stakingCarolBalanceBefore, INITIAL_BALANCE);
    }

    /* ================= USER ACTIONS ================= */

    function test_stake_pass_oneUser_oneEntity() public {
        _cacheBalancesBefore();

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

        assertEq(stakingToken.balanceOf(address(stakingRewards)), stakingContractBalanceBefore + stakeAmount1);
        assertEq(stakingToken.balanceOf(alice), stakingAliceBalanceBefore - stakeAmount1);
        assertEq(stakingToken.balanceOf(bob), stakingBobBalanceBefore);
        assertEq(stakingToken.balanceOf(carol), stakingCarolBalanceBefore);

        assertEq(rewardToken.balanceOf(address(stakingRewards)), rewardContractBalanceBefore);
        assertEq(rewardToken.balanceOf(alice), rewardAliceBalanceBefore);
        assertEq(rewardToken.balanceOf(bob), rewardBobBalanceBefore);
        assertEq(rewardToken.balanceOf(carol), rewardCarolBalanceBefore);
    }

    function test_stake_pass_oneUser_multipleEntities() public {
        _cacheBalancesBefore();

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

        assertEq(
            stakingToken.balanceOf(address(stakingRewards)), stakingContractBalanceBefore + stakeAmount1 + stakeAmount2
        );
        assertEq(stakingToken.balanceOf(alice), stakingAliceBalanceBefore - stakeAmount1 - stakeAmount2);
        assertEq(stakingToken.balanceOf(bob), stakingBobBalanceBefore);
        assertEq(stakingToken.balanceOf(carol), stakingCarolBalanceBefore);

        assertEq(rewardToken.balanceOf(address(stakingRewards)), rewardContractBalanceBefore);
        assertEq(rewardToken.balanceOf(alice), rewardAliceBalanceBefore);
        assertEq(rewardToken.balanceOf(bob), rewardBobBalanceBefore);
        assertEq(rewardToken.balanceOf(carol), rewardCarolBalanceBefore);
    }

    function test_stake_pass_multipleUsers_oneEntity() public {
        _cacheBalancesBefore();

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

        assertEq(
            stakingToken.balanceOf(address(stakingRewards)), stakingContractBalanceBefore + stakeAmount1 + stakeAmount2
        );
        assertEq(stakingToken.balanceOf(alice), stakingAliceBalanceBefore - stakeAmount1);
        assertEq(stakingToken.balanceOf(bob), stakingBobBalanceBefore - stakeAmount2);
        assertEq(stakingToken.balanceOf(carol), stakingCarolBalanceBefore);

        assertEq(rewardToken.balanceOf(address(stakingRewards)), rewardContractBalanceBefore);
        assertEq(rewardToken.balanceOf(alice), rewardAliceBalanceBefore);
        assertEq(rewardToken.balanceOf(bob), rewardBobBalanceBefore);
        assertEq(rewardToken.balanceOf(carol), rewardCarolBalanceBefore);
    }

    function test_stake_pass_multipleUsers_multipleEntities() public {
        _cacheBalancesBefore();

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
            stakingContractBalanceBefore + stakeAmount1 + stakeAmount2 + stakeAmount3
        );
        assertEq(stakingToken.balanceOf(alice), stakingAliceBalanceBefore - stakeAmount1);
        assertEq(stakingToken.balanceOf(bob), stakingBobBalanceBefore - stakeAmount2);
        assertEq(stakingToken.balanceOf(carol), stakingCarolBalanceBefore - stakeAmount3);

        assertEq(rewardToken.balanceOf(address(stakingRewards)), rewardContractBalanceBefore);
        assertEq(rewardToken.balanceOf(alice), rewardAliceBalanceBefore);
        assertEq(rewardToken.balanceOf(bob), rewardBobBalanceBefore);
        assertEq(rewardToken.balanceOf(carol), rewardCarolBalanceBefore);
    }

    function test_stake_revert_zeroAmount() public {
        vm.startPrank(alice);
        vm.expectRevert("amount = 0");
        stakingRewards.stake(entity1, 0);
        vm.stopPrank();
    }

    function test_withdraw_pass_oneUser_oneEntity() public {
        vm.prank(alice);
        stakingRewards.stake(entity1, stakeAmount1);

        _cacheBalancesBefore();

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

        assertEq(stakingToken.balanceOf(address(stakingRewards)), stakingContractBalanceBefore - stakeAmount1);
        assertEq(stakingToken.balanceOf(alice), stakingAliceBalanceBefore + stakeAmount1);
        assertEq(stakingToken.balanceOf(bob), stakingBobBalanceBefore);
        assertEq(stakingToken.balanceOf(carol), stakingCarolBalanceBefore);

        assertEq(rewardToken.balanceOf(address(stakingRewards)), rewardContractBalanceBefore);
        assertEq(rewardToken.balanceOf(alice), rewardAliceBalanceBefore);
        assertEq(rewardToken.balanceOf(bob), rewardBobBalanceBefore);
        assertEq(rewardToken.balanceOf(carol), rewardCarolBalanceBefore);
    }

    function test_withdraw_pass_oneUser_multipleEntities() public {
        vm.prank(alice);
        stakingRewards.stake(entity1, stakeAmount1);

        vm.prank(alice);
        stakingRewards.stake(entity2, stakeAmount2);

        _cacheBalancesBefore();

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

        assertEq(
            stakingToken.balanceOf(address(stakingRewards)), stakingContractBalanceBefore - stakeAmount1 - stakeAmount2
        );
        assertEq(stakingToken.balanceOf(alice), stakingAliceBalanceBefore + stakeAmount1 + stakeAmount2);
        assertEq(stakingToken.balanceOf(bob), stakingBobBalanceBefore);
        assertEq(stakingToken.balanceOf(carol), stakingCarolBalanceBefore);

        assertEq(rewardToken.balanceOf(address(stakingRewards)), rewardContractBalanceBefore);
        assertEq(rewardToken.balanceOf(alice), rewardAliceBalanceBefore);
        assertEq(rewardToken.balanceOf(bob), rewardBobBalanceBefore);
        assertEq(rewardToken.balanceOf(carol), rewardCarolBalanceBefore);
    }

    function test_withdraw_pass_multipleUsers_oneEntity() public {
        vm.prank(alice);
        stakingRewards.stake(entity1, stakeAmount1);

        vm.prank(bob);
        stakingRewards.stake(entity1, stakeAmount2);

        _cacheBalancesBefore();

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

        assertEq(
            stakingToken.balanceOf(address(stakingRewards)), stakingContractBalanceBefore - stakeAmount1 - stakeAmount2
        );
        assertEq(stakingToken.balanceOf(alice), stakingAliceBalanceBefore + stakeAmount1);
        assertEq(stakingToken.balanceOf(bob), stakingBobBalanceBefore + stakeAmount2);
        assertEq(stakingToken.balanceOf(carol), stakingCarolBalanceBefore);

        assertEq(rewardToken.balanceOf(address(stakingRewards)), rewardContractBalanceBefore);
        assertEq(rewardToken.balanceOf(alice), rewardAliceBalanceBefore);
        assertEq(rewardToken.balanceOf(bob), rewardBobBalanceBefore);
        assertEq(rewardToken.balanceOf(carol), rewardCarolBalanceBefore);
    }

    function test_withdraw_pass_multipleUsers_multipleEntities() public {
        vm.prank(alice);
        stakingRewards.stake(entity1, stakeAmount1);

        vm.prank(bob);
        stakingRewards.stake(entity1, stakeAmount2);

        vm.prank(carol);
        stakingRewards.stake(entity2, stakeAmount3);

        _cacheBalancesBefore();

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
            stakingContractBalanceBefore - stakeAmount1 - stakeAmount2 - stakeAmount3
        );
        assertEq(stakingToken.balanceOf(alice), stakingAliceBalanceBefore + stakeAmount1);
        assertEq(stakingToken.balanceOf(bob), stakingBobBalanceBefore + stakeAmount2);
        assertEq(stakingToken.balanceOf(carol), stakingCarolBalanceBefore + stakeAmount3);

        assertEq(rewardToken.balanceOf(address(stakingRewards)), rewardContractBalanceBefore);
        assertEq(rewardToken.balanceOf(alice), rewardAliceBalanceBefore);
        assertEq(rewardToken.balanceOf(bob), rewardBobBalanceBefore);
        assertEq(rewardToken.balanceOf(carol), rewardCarolBalanceBefore);
    }

    function test_withdraw_revert_zeroAmount() public {
        vm.prank(alice);
        stakingRewards.stake(entity1, stakeAmount1);

        vm.startPrank(alice);
        vm.expectRevert("amount = 0");
        stakingRewards.withdraw(entity1, 0);
        vm.stopPrank();
    }

    function test_withdraw_revert_insufficientStake() public {
        vm.prank(alice);
        stakingRewards.stake(entity1, stakeAmount1);

        vm.startPrank(alice);
        vm.expectRevert("insufficient stake");
        stakingRewards.withdraw(entity1, stakeAmount1 + 1);
        vm.stopPrank();
    }

    function test_claim_pass_oneUser_oneEntity() public {
        vm.prank(alice);
        stakingRewards.stake(entity1, stakeAmount1);

        skip(timeElapsed);

        _cacheBalancesBefore();
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

        assertEq(stakingToken.balanceOf(address(stakingRewards)), stakingContractBalanceBefore);
        assertEq(stakingToken.balanceOf(alice), stakingAliceBalanceBefore);
        assertEq(stakingToken.balanceOf(bob), stakingBobBalanceBefore);
        assertEq(stakingToken.balanceOf(carol), stakingCarolBalanceBefore);

        assertEq(rewardToken.balanceOf(address(stakingRewards)), rewardContractBalanceBefore - earnedRewards1);
        assertEq(rewardToken.balanceOf(alice), rewardAliceBalanceBefore + earnedRewards1);
        assertEq(rewardToken.balanceOf(bob), rewardBobBalanceBefore);
        assertEq(rewardToken.balanceOf(carol), rewardCarolBalanceBefore);
    }

    function test_claim_pass_oneUser_multipleEntities() public {
        vm.prank(alice);
        stakingRewards.stake(entity1, stakeAmount1);

        vm.prank(alice);
        stakingRewards.stake(entity2, stakeAmount2);

        skip(timeElapsed);

        _cacheBalancesBefore();
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

        assertEq(stakingToken.balanceOf(address(stakingRewards)), stakingContractBalanceBefore);
        assertEq(stakingToken.balanceOf(alice), stakingAliceBalanceBefore);
        assertEq(stakingToken.balanceOf(bob), stakingBobBalanceBefore);
        assertEq(stakingToken.balanceOf(carol), stakingCarolBalanceBefore);

        assertEq(
            rewardToken.balanceOf(address(stakingRewards)),
            rewardContractBalanceBefore - earnedRewards1 - earnedRewards2
        );
        assertEq(rewardToken.balanceOf(alice), rewardAliceBalanceBefore + earnedRewards1 + earnedRewards2);
        assertEq(rewardToken.balanceOf(bob), rewardBobBalanceBefore);
        assertEq(rewardToken.balanceOf(carol), rewardCarolBalanceBefore);
    }

    function test_claim_pass_multipleUsers_oneEntity() public {
        vm.prank(alice);
        stakingRewards.stake(entity1, stakeAmount1);

        vm.prank(bob);
        stakingRewards.stake(entity1, stakeAmount2);

        skip(timeElapsed);

        _cacheBalancesBefore();
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

        assertEq(stakingToken.balanceOf(address(stakingRewards)), stakingContractBalanceBefore);
        assertEq(stakingToken.balanceOf(alice), stakingAliceBalanceBefore);
        assertEq(stakingToken.balanceOf(bob), stakingBobBalanceBefore);
        assertEq(stakingToken.balanceOf(carol), stakingCarolBalanceBefore);

        assertEq(
            rewardToken.balanceOf(address(stakingRewards)),
            rewardContractBalanceBefore - earnedRewards1 - earnedRewards2
        );
        assertEq(rewardToken.balanceOf(alice), rewardAliceBalanceBefore + earnedRewards1);
        assertEq(rewardToken.balanceOf(bob), rewardBobBalanceBefore + earnedRewards2);
        assertEq(rewardToken.balanceOf(carol), rewardCarolBalanceBefore);
    }

    function test_claim_pass_multipleUsers_multipleEntities() public {
        vm.prank(alice);
        stakingRewards.stake(entity1, stakeAmount1);

        vm.prank(bob);
        stakingRewards.stake(entity1, stakeAmount2);

        vm.prank(carol);
        stakingRewards.stake(entity2, stakeAmount3);

        skip(timeElapsed);

        _cacheBalancesBefore();
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

        assertEq(stakingToken.balanceOf(address(stakingRewards)), stakingContractBalanceBefore);
        assertEq(stakingToken.balanceOf(alice), stakingAliceBalanceBefore);
        assertEq(stakingToken.balanceOf(bob), stakingBobBalanceBefore);
        assertEq(stakingToken.balanceOf(carol), stakingCarolBalanceBefore);

        assertEq(
            rewardToken.balanceOf(address(stakingRewards)),
            rewardContractBalanceBefore - earnedRewards1 - earnedRewards2 - earnedRewards3
        );
        assertEq(rewardToken.balanceOf(alice), rewardAliceBalanceBefore + earnedRewards1);
        assertEq(rewardToken.balanceOf(bob), rewardBobBalanceBefore + earnedRewards2);
        assertEq(rewardToken.balanceOf(carol), rewardCarolBalanceBefore + earnedRewards3);
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

    function _cacheBalancesBefore() internal {
        stakingContractBalanceBefore = stakingToken.balanceOf(address(stakingRewards));
        stakingAliceBalanceBefore = stakingToken.balanceOf(alice);
        stakingBobBalanceBefore = stakingToken.balanceOf(bob);
        stakingCarolBalanceBefore = stakingToken.balanceOf(carol);

        rewardContractBalanceBefore = rewardToken.balanceOf(address(stakingRewards));
        rewardAliceBalanceBefore = rewardToken.balanceOf(alice);
        rewardBobBalanceBefore = rewardToken.balanceOf(bob);
        rewardCarolBalanceBefore = rewardToken.balanceOf(carol);
    }

    function _getEarnedExpected(uint256 actorStake, uint256 entityStaked, uint256 globalStaked)
        internal
        view
        returns (uint256)
    {
        return (actorStake * ENTITY_EMISSION_RATE * GLOBAL_EMISSION_RATE * timeElapsed) / (entityStaked * globalStaked);
    }
}
