// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script} from "lib/forge-std/src/Script.sol";
import {console2} from "lib/forge-std/src/console2.sol";

import {StakingRewards} from "src/StakingRewards.sol";

contract StakingRewardsScript is Script {
    function run() external returns (StakingRewards) {
        address stakingToken = vm.envAddress("STAKING_TOKEN_ADDRESS");
        address rewardToken = vm.envAddress("REWARD_TOKEN_ADDRESS");
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        console2.log("Deploying StakingRewards...");
        console2.log("Staking Token:", stakingToken);
        console2.log("Reward Token:", rewardToken);
        console2.log("Deployer:", vm.addr(deployerPrivateKey));

        vm.startBroadcast(deployerPrivateKey);

        StakingRewards stakingRewards = new StakingRewards(stakingToken, rewardToken);

        vm.stopBroadcast();

        console2.log("StakingRewards deployed at:", address(stakingRewards));

        return stakingRewards;
    }
}
