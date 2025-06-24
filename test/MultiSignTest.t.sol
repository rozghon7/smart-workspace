//SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {Test, console} from "forge-std/Test.sol";
import "../src/MultiSign.sol";

contract MultiSignTest is Test {
    MultiSign multis;
    address[] signers;
    uint256 quorum = 2;
    address[] signersArray;

    address sig1 = vm.addr(1);
    address sig2 = vm.addr(2);
    address sig3 = vm.addr(3);

    address recepientAddress = vm.addr(777);

    function setUp() public {
        signers.push(sig1);
        signers.push(sig2);
        signers.push(sig3);

        multis = new MultiSign(signers, quorum);
    }

    function fundContract(uint256 amount) internal {
        vm.deal(address(multis), amount);
    }

    function test_initTransferRevertsIfNoEtherOnContract() public {
        vm.prank(sig1);
        vm.expectRevert(MultiSign.ContractBalanceIsZero.selector);
        console.log("Address to", recepientAddress, "Contract balance", (address(multis).balance));
        multis.initiateTransfer(recepientAddress, 7 ether);
    }

    function test_initTransferRevertsBecauseTransferToCannotBeZeroAddress() public {
        address recepient = address(0);
        vm.prank(sig1);
        vm.expectRevert(MultiSign.TransferToCannotBeZeroAddress.selector);

        multis.initiateTransfer(recepient, 7 ether);
    }

    function test_initTransferRevertsBecauseTransferAmountMustBeGreaterThanZero() public {
        vm.prank(sig1);
        vm.expectRevert(MultiSign.TransferAmountMustBeGreaterThanZero.selector);

        multis.initiateTransfer(recepientAddress, 0 ether);
    }

    function test_initiateTransferFunctionalityCheck() public {
        vm.prank(sig1);

        fundContract(10 ether);

        vm.expectEmit(true, true, false, true);
        emit MultiSign.TransferInitiated(0, recepientAddress, 7 ether);

        multis.initiateTransfer(recepientAddress, 7 ether);

        (address _to, uint256 _amount, uint256 _approvalCount, bool _executed) = multis.getTransferInfo(0);
        assertEq(_to, recepientAddress);
        assertEq(_amount, 7 ether);
        assertEq(_approvalCount, 1);
        assertEq(_executed, false);
    }

    function test_approveTransferFunctionalityCheck() public {
        vm.prank(sig1);
        fundContract(10 ether);
        multis.initiateTransfer(recepientAddress, 7 ether);

        vm.prank(sig1);
        vm.expectRevert(MultiSign.AlreadyApprovedBySigner.selector);
        multis.approveTransfer(0);

        // vm.expectEmit(true, true, false, false);
        // emit MultiSign.TransferApproved(0, sig1);

        vm.prank(sig2);
        multis.approveTransfer(0);

        vm.prank(sig3);
        multis.approveTransfer(0);

        (,, uint256 _approvalCount,) = multis.getTransferInfo(0);
        assertEq(_approvalCount, 3);
    }

    function test_approveTransferEventCheck() public {
        vm.prank(sig1);
        fundContract(10 ether);
        multis.initiateTransfer(recepientAddress, 7 ether);

        vm.expectEmit(true, true, false, false);
        emit MultiSign.TransferApproved(0, sig2);

        vm.prank(sig2);
        multis.approveTransfer(0);
    }

    function test_excuteTransferReverts() public {
        vm.startPrank(sig1);
        fundContract(10 ether);
        multis.initiateTransfer(recepientAddress, 7 ether);

        (,, uint256 _approvalCount,) = multis.getTransferInfo(0);

        vm.expectRevert(abi.encodeWithSelector(MultiSign.QuorumNotReached.selector, quorum, _approvalCount));

        multis.executeTransfer(0);

        vm.startPrank(sig2);
        multis.approveTransfer(0);

        vm.expectEmit(true, true, false, true);
        emit MultiSign.TransferExecuted(0, recepientAddress, 7 ether);
        multis.executeTransfer(0);
    }

    function test_excuteTransferWorks() public {
        vm.startPrank(sig1);
        fundContract(10 ether);
        multis.initiateTransfer(recepientAddress, 7 ether);

        vm.startPrank(sig2);
        multis.approveTransfer(0);
        multis.executeTransfer(0);

        (address _to, uint256 _amount, uint256 _approvalCount, bool _executed) = multis.getTransferInfo(0);
        assertEq(_to, recepientAddress);
        assertEq(_amount, 7 ether);
        assertEq(_approvalCount, 2);
        assertEq(_executed, true);
    }

    function test_HasSignedStatusFunctionalityCheck() public {
        vm.startPrank(sig1);
        fundContract(10 ether);
        multis.initiateTransfer(recepientAddress, 7 ether);

        bool _signed = multis.signedStatus(sig1, 0);
        assertEq(_signed, true);
    }

    function test_getTransferCountFunctionalityCheck() public {
        uint256 beforeFirstTransferInit = multis.getTransfersCount();
        assertEq(beforeFirstTransferInit, 0);

        vm.startPrank(sig1);
        fundContract(10 ether);
        multis.initiateTransfer(recepientAddress, 7 ether);

        uint256 afterFirstTransferInit = multis.getTransfersCount();
        assertEq(afterFirstTransferInit, 1);
    }

    function test_onlyMultisignerCheck() public {
        address randomAddress = vm.addr(777);

        vm.startPrank(sig1);
        fundContract(10 ether);
        multis.initiateTransfer(recepientAddress, 7 ether);

        vm.startPrank(randomAddress);
        vm.expectRevert(MultiSign.OnlySignerAllowed.selector);
        multis.approveTransfer(0);
    }

    function test_constructorRevertZeroSignersCheck() public {
        address[] memory emptySigArray;

        vm.expectRevert(MultiSign.SignersLengthMustBeGreaterThanZero.selector);
        new MultiSign(emptySigArray, quorum);
    }

    function test_constructorRevertsSignersVsQuorumLengthCheck() public {
        signersArray.push(sig1);
        signersArray.push(sig2);

        vm.expectRevert(MultiSign.SignersLengthCantBeLessThanQuorum.selector);
        new MultiSign(signersArray, 3);
    }

    function test_constructorRevertsZeroQuorumCheck() public {
        signersArray.push(sig1);
        signersArray.push(sig2);

        vm.expectRevert(MultiSign.QuorumMustBeGreaterThanZero.selector);
        new MultiSign(signersArray, 0);
    }
}
