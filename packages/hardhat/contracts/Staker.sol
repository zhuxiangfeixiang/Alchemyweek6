// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "hardhat/console.sol";
import "./ExampleExternalContract.sol";

contract Staker {

  ExampleExternalContract public exampleExternalContract;

  mapping(address => uint256) public balances;
  mapping(address => uint256) public depositTimestamps;

  uint256 public constant rewardRatePerBlock = 0.1 ether;
  // Set withdrawTime to 120 for 2 minutes by default
  uint256 public withdrawTime = 120;
  uint256 public withdrawalDeadline = block.timestamp + (withdrawTime * 1 seconds);
  // Set claimTime to 240 for 4 minutes by default
  uint256 public claimTime = 240;
  uint256 public claimDeadline = block.timestamp + (claimTime * 1 seconds);
  uint256 public currentBlock = 0;
  // Exponential money!!
  uint256 public exponentMultiplier = 2;

  // Whitelist so that only the exampleExternalContract can modify
  address public contractWhitelist;

  // Events
  event Stake(address indexed sender, uint256 amount);
  event Received(address, uint);
  event Execute(address indexed sender, uint256 amount);

  // Modifiers
  /*
  Checks if the withdrawal period has been reached or not
  */
  modifier withdrawalDeadlineReached( bool requireReached ) {
    uint256 timeRemaining = withdrawalTimeLeft();
    if( requireReached ) {
      require(timeRemaining == 0, "Withdrawal period is not reached yet");
    } else {
      require(timeRemaining > 0, "Withdrawal period has been reached");
    }
    _;
  }

  /*
  Checks if the claim period has ended or not
  */
  modifier claimDeadlineReached( bool requireReached ) {
    uint256 timeRemaining = claimPeriodLeft();
    if( requireReached ) {
      require(timeRemaining == 0, "Claim deadline is not reached yet");
    } else {
      require(timeRemaining > 0, "Claim deadline has been reached");
    }
    _;
  }

  /*
  Requires that the contract only be completed once!
  */
  modifier notCompleted() {
    bool completed = exampleExternalContract.completed();
    require(!completed, "Stake already completed!");
    _;
  }

  constructor(address exampleExternalContractAddress){
      exampleExternalContract = ExampleExternalContract(exampleExternalContractAddress);
      contractWhitelist = exampleExternalContractAddress;
  }

  // Stake function for a user to stake ETH in our contract
  function stake() public payable withdrawalDeadlineReached(false) claimDeadlineReached(false){
    balances[msg.sender] = balances[msg.sender] + msg.value;
    depositTimestamps[msg.sender] = block.timestamp;
    emit Stake(msg.sender, msg.value);
  }

  /*
  Withdraw function for a user to remove their staked ETH inclusive
  of both principal and any accrued interest
  */
  function withdraw() public withdrawalDeadlineReached(true) claimDeadlineReached(false) notCompleted{
    require(balances[msg.sender] > 0, "You have no balance to withdraw!");
    uint256 individualBalance = balances[msg.sender];
    // get the time passed
    uint256 rewardTime = block.timestamp-depositTimestamps[msg.sender];
    // multiply time passed by exponent
    uint256 rewardsMultiplied = rewardTime**exponentMultiplier;
    // add initial balance to reward rate
    uint256 indBalanceRewards = individualBalance + (rewardsMultiplied*rewardRatePerBlock);
    balances[msg.sender] = 0;

    // Transfer all ETH via call! (not transfer) cc: https://solidity-by-example.org/sending-ether
    (bool sent, bytes memory data) = msg.sender.call{value: indBalanceRewards}("");
    require(sent, "Failed to send ETH");
  }

  /*
  Allows any user to repatriate "unproductive" funds that are left in the staking contract
  past the defined withdrawal period
  */
  function execute() public claimDeadlineReached(true) notCompleted {
    uint256 contractBalance = address(this).balance;
    exampleExternalContract.complete{value: address(this).balance}();
  }

  // Functions added for reset:

  /*
  Reset withdrawalDeadline blocktime
  Requires withdrawalDeadlineReached to be true
  */
  function resetWithdrawalDeadline(uint256 _seconds) withdrawalDeadlineReached(true) public {
    require(msg.sender == contractWhitelist, "You are not the exampleExternalContract");
    withdrawalDeadline = block.timestamp + (_seconds * 1 seconds);
  }

  /*
  Reset claimDeadline blocktime
  Requires claimDeadlineReached to be true
  */
  function resetClaimDeadline(uint256 _seconds) claimDeadlineReached(true) public {
    require(msg.sender == contractWhitelist, "You are not the exampleExternalContract");
    claimDeadline = block.timestamp + (_seconds * 1 seconds);
  }

  /*
  READ-ONLY function to calculate the time remaining before the minimum staking period has passed
  */
  function withdrawalTimeLeft() public view returns (uint256 withdrawalTimeLeft) {
    if( block.timestamp >= withdrawalDeadline) {
      return (0);
    } else {
      return (withdrawalDeadline - block.timestamp);
    }
  }


  /*
  READ-ONLY function to calculate the time remaining before the minimum staking period has passed
  */
  function claimPeriodLeft() public view returns (uint256 claimPeriodLeft) {
    if( block.timestamp >= claimDeadline) {
      return (0);
    } else {
      return (claimDeadline - block.timestamp);
    }
  }

  /*
  Time to "kill-time" on our local testnet
  */
  function killTime() public {
    currentBlock = block.timestamp;
  }

  /*
  \Function for our smart contract to receive ETH
  cc: https://docs.soliditylang.org/en/latest/contracts.html#receive-ether-function
  */
  receive() external payable {
      emit Received(msg.sender, msg.value);
  }

}
