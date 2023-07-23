pragma solidity ^0.8.12;

import "./ERC20Interface.sol";
import "./SafeMathUint2.sol";
import "./SafeMathInt2.sol";

contract BCKSavingsAccount {
  using SafeMathUint for uint256;
  using SafeMathInt for int256;

  ERC20Interface public bck;
  ERC20Interface public usdc;
  address public owner;

  uint256 constant internal magnitude = 2**128;
  uint256 internal magnifiedInterestPerShare;
  mapping(address => int256) internal magnifiedInterestCorrections;
  mapping(address => uint256) internal withdrawnInterest;

  mapping(address => uint256) public balances;
  uint256 public totalDeposits;
  event USDCDistributed(address indexed from, uint256 value);


  constructor(address _bck, address _usdc) public {
    bck = ERC20Interface(_bck);
    usdc = ERC20Interface(_usdc);
    owner = msg.sender;
  }

  modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

function depositBCK(uint256 _amount) public {
    require(bck.transferFrom(msg.sender, address(this), _amount), "BCK transfer failed");

    // Before updating the balances and totalDeposits, adjust the magnifiedInterestCorrections
    // of the depositor based on their increased stake.
    magnifiedInterestCorrections[msg.sender] = magnifiedInterestCorrections[msg.sender]
        .sub( (magnifiedInterestPerShare.mul(_amount)).toInt256Safe() );

    balances[msg.sender] = balances[msg.sender].add(_amount);
    totalDeposits = totalDeposits.add(_amount);
}


function withdrawBCK(uint256 _amount) public {
    require(balances[msg.sender] >= _amount, "Insufficient BCK balance");

    // Before updating the balances and totalDeposits, adjust the magnifiedInterestCorrections
    // of the withdrawer based on their decreased stake.
    magnifiedInterestCorrections[msg.sender] = magnifiedInterestCorrections[msg.sender]
        .add( (magnifiedInterestPerShare.mul(_amount)).toInt256Safe() );

    balances[msg.sender] = balances[msg.sender].sub(_amount);
    totalDeposits = totalDeposits.sub(_amount);
    require(bck.transfer(msg.sender, _amount), "BCK transfer failed");
}

function distributeUSDC(uint256 _amount) public {
    // Check if the owner has enough USDC
    uint256 ownerUSDCBalance = usdc.balanceOf(msg.sender);
    require(ownerUSDCBalance >= _amount, "Owner has insufficient USDC balance");

    // Calculate the magnified interest per share
    if (totalDeposits > 0) {
        magnifiedInterestPerShare = magnifiedInterestPerShare.add(
            (_amount).mul(magnitude).div(totalDeposits)
        );
    }

    // Emit an event to inform external observers about the distribution
    emit USDCDistributed(msg.sender, _amount);

    // Transfer the USDC from the owner to the contract
    require(usdc.transferFrom(msg.sender, address(this), _amount), "USDC transfer failed");
}

  function withdrawInterest() public {
    uint256 _withdrawableInterest = withdrawableInterestOf(msg.sender);
    if (_withdrawableInterest > 0) {
            withdrawnInterest[msg.sender] = withdrawnInterest[msg.sender].add(_withdrawableInterest);
      require(usdc.transfer(msg.sender, _withdrawableInterest), "USDC transfer failed");
    }
  }

  function interestOf(address _owner) public view returns(uint256) {
    return accumulativeInterestOf(_owner).sub(withdrawnInterest[_owner]);
  }

  function withdrawableInterestOf(address _owner) public view returns(uint256) {
    return accumulativeInterestOf(_owner).sub(withdrawnInterest[_owner]);
  }

  function accumulativeInterestOf(address _owner) public view returns(uint256) {
    return magnifiedInterestPerShare.mul(balances[_owner]).toInt256Safe()
      .add(magnifiedInterestCorrections[_owner]).toUint256Safe() / magnitude;
  }
}

