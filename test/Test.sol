// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {StakingDapp} from "../src/Staking.sol";

contract StakingDappTest is Test {
    StakingDapp public stakingDapp;
    address newOwner = address(0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266);
    address user = address(0x90F79bf6EB2c4f870365E785982E1f101E93b906);
    address user2 = address(0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC);
    address user3 = address(0xa0Ee7A142d267C1f36714E4a8F75612F20a79720);
    uint256 public minStakeTime = 30 days;

    function setUp() public {
        vm.deal(address(this), 10 ether);
        stakingDapp = new StakingDapp{value: 10 ether}();
        vm.deal(user, 10 ether);
        vm.deal(user2, 10 ether);
        vm.deal(user3, 10 ether);
        vm.startPrank(user);
        stakingDapp.stake{value: 1 ether}();
        vm.stopPrank();
    }

    function abs(int256 x) public pure returns (uint256) {
        return x < 0 ? uint256(-x) : uint256(x);
    }

    function testOwnerIsMsgSender() public {
        assertEq(stakingDapp.getOwner(), address(this));
    }

    function testMinUSDToStake() public {
        uint256 minVal = stakingDapp.MIN_VALUE();
        assertEq(minVal, 1 ether);
    }

    function testMinStakeTime() public {
        uint256 minStake = stakingDapp.minStakeTime();
        assertEq(minStake, 30 days);
    }

    function testTransferOwnership() public {
        vm.startPrank(address(this));
        stakingDapp.transferOwnership(newOwner);
        assertEq(stakingDapp.getOwner(), newOwner);
        vm.stopPrank();
    }

    function testUserCanStake() public {
        vm.deal(user, 1 ether);
        vm.startPrank(user);
        stakingDapp.stake{value: 1 ether}();
        vm.stopPrank();
        assertEq(stakingDapp.s_stakes(user), 2 ether);
    }

    function testAddStake() public {
        uint256 stakeAmount = 1 ether;
        uint256 initialStake = stakingDapp.s_stakes(user);

        vm.startPrank(user);
        stakingDapp.stake{value: stakeAmount}();
        vm.stopPrank();

        uint256 newStake = stakingDapp.s_stakes(user);
        assertEq(
            newStake,
            initialStake + stakeAmount,
            "User's stake should increase by the staked amount"
        );
    }

    function testUnstake() public {
        vm.warp(block.timestamp + 31 days);
        vm.startPrank(user);
        stakingDapp.unstake();
        vm.stopPrank();
        assertEq(stakingDapp.s_stakes(user), 0, "User should have 0 ETH");
    }

    function testUnStakeBeforeTime() public {
        uint256 stakeAmount = 1 ether;
        vm.startPrank(user2);
        stakingDapp.stake{value: stakeAmount}();
        vm.stopPrank();

        vm.warp(block.timestamp + 15 days);

        vm.startPrank(user2);
        vm.expectRevert("Staking duration is too short");
        stakingDapp.unstake();
        vm.stopPrank();

        assertEq(stakingDapp.s_stakes(user2), stakeAmount);
    }

    function testUnstakeWithoutStake() public {
        vm.startPrank(user2);
        vm.expectRevert("No staked funds");
        stakingDapp.unstake();
        vm.stopPrank();
    }

    function testCorrectRewardAfterStaking() public {
        uint256 stakeAmount = 1 ether;

        vm.startPrank(user3);
        stakingDapp.stake{value: stakeAmount}();
        vm.stopPrank();

        vm.warp(block.timestamp + 90 days);

        uint256 expectedReward = (((stakeAmount * 5) / 100) * (90 days)) /
            365 days;
        vm.startPrank(user3);
        uint256 reward = stakingDapp.getReward(user3);
        vm.stopPrank();

        assertApproxEqAbs(
            reward,
            expectedReward,
            1e14,
            "Incorrect reward calculation"
        );
    }

    function testOwnerCannotUnstakeOtherUsersFunds() public {
        vm.startPrank(stakingDapp.owner());
        vm.expectRevert("No staked funds");
        stakingDapp.unstake();
        vm.stopPrank();
    }

    function testPauseStaking() public {
        stakingDapp.pauseStaking();
        vm.startPrank(user);
        vm.expectRevert("Staking is paused");
        stakingDapp.stake{value: 1 ether}();
        vm.stopPrank();
    }

    function testAddStakeWhenPaused() public {
        stakingDapp.pauseStaking();
        uint256 initialStake = stakingDapp.s_stakes(user);

        vm.startPrank(user);
        vm.expectRevert("Staking is paused");
        stakingDapp.addStake{value: 1 ether}();
        vm.stopPrank();

        assertEq(
            stakingDapp.s_stakes(user),
            initialStake,
            "User's stake should not increase"
        );
    }

    function testRewardAfterMinStakeTime() public {
        uint256 stakeAmount = 1 ether;
        uint256 stakingDuration = 30 days;

        vm.startPrank(user2);
        stakingDapp.stake{value: stakeAmount}();
        vm.stopPrank();

        vm.warp(block.timestamp + stakingDuration + 1 days);

        uint256 expectedReward = (stakeAmount * 5 * stakingDuration) /
            (100 * 365 days);

        vm.startPrank(user2);
        uint256 reward = stakingDapp.getReward(user2);
        vm.stopPrank();

        console.log("Reward: ", reward);
        console.log("Expected Reward: ", expectedReward);

        uint256 tolerance = 150000000000000;
        assertTrue(
            abs(int256(reward) - int256(expectedReward)) <= tolerance,
            "Reward calculation is incorrect."
        );
    }

    function testContractBalance() public {
        uint256 initialBalance = address(stakingDapp).balance;

        uint256 stakeAmount = 1 ether;
        vm.startPrank(user2);
        stakingDapp.stake{value: stakeAmount}();
        vm.stopPrank();

        uint256 expectedBalance = initialBalance + stakeAmount;

        uint256 currentBalance = address(stakingDapp).balance;
        assertEq(
            currentBalance,
            expectedBalance,
            "Contract balance is incorrect."
        );
    }

    function testStakeAndGetStakeInfo() public {
        vm.prank(user2);
        stakingDapp.stake{value: 1 ether}();

        (
            uint256 stakedAmount,
            uint256 reward,
            uint256 stakingTime
        ) = stakingDapp.userGetStakeInfo(user2);

        assertEq(stakedAmount, 1 ether, "Staked amount should be 1 ether");

        assertEq(reward, 0, "Initial reward should be 0");

        assertTrue(stakingTime > 0, "Staking time should be greater than 0");
    }
}
