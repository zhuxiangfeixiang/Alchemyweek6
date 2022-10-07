// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "./Staker.sol";

contract ExampleExternalContract {

  Staker public staker;

  bool public completed;

  function setStakerContractAddress(address payable stakerContractAddress) public {
    staker = Staker(stakerContractAddress);
  }

  function complete() public payable {
    completed = true;
  }

  function resetStaker(uint _claimtime, uint256 _withdrawtime) public {
    require(completed = true, "Sorry, cannot run this yet.");
    completed = false;
    staker.resetWithdrawalDeadline(_withdrawtime);
    staker.resetClaimDeadline(_claimtime);
    (bool sent, bytes memory data) = address(staker).call{value: address(this).balance}("");
    require(sent, "Failed to send Ether");
  }

}
