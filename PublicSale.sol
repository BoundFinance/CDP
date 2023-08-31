// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";


interface IERC20Token {
    function balanceOf(address owner) external returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function decimals() external returns (uint8);
    function transferFrom(address user1, address user2, uint256 amount) external returns (bool);
}

contract TokenSale is ReentrancyGuard {
    IERC20Token public tokenContract;  // the token being sold
    uint256 public price;              // the price, in wei, per token
    address public owner;
    uint256 public tokensSold;

    event Sold(address indexed buyer, uint256 amount);
    event BoughtBack(address indexed seller, uint256 amount);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    modifier onlyOwner() {
        require(msg.sender == owner, "You are not the owner");
        _;
    }


    constructor(IERC20Token _tokenContract, uint256 _price) {
        owner = msg.sender;
        tokenContract = _tokenContract;
        price = _price;
    }

    function buyTokens(uint256 numberOfTokens) public payable nonReentrant {
        require(msg.value == numberOfTokens * price, "Mismatched value sent");

        uint256 scaledAmount = numberOfTokens * (10 ** uint256(tokenContract.decimals()));

        require(tokenContract.balanceOf(address(this)) >= scaledAmount, "Insufficient tokens");

        tokensSold += numberOfTokens;

        emit Sold(msg.sender, numberOfTokens);

        require(tokenContract.transfer(msg.sender, scaledAmount), "Token transfer failed");
    }

    function sellTokens(uint256 numberOfTokens) public nonReentrant {
        
        uint256 scaledAmount = numberOfTokens * (10 ** uint256(tokenContract.decimals()));

        require(tokenContract.balanceOf(msg.sender) >= scaledAmount, "Insufficient tokens to sell");

        require(address(this).balance >= numberOfTokens * price, "Insufficient ETH in contract");

        tokensSold -= numberOfTokens;

        emit BoughtBack(msg.sender, numberOfTokens);

        require(tokenContract.transferFrom(msg.sender, address(this), scaledAmount), "Token transfer failed");

        payable(msg.sender).transfer(numberOfTokens * price);
    }

    function endSale() public onlyOwner nonReentrant {
        // Send unsold tokens to the owner.
        require(tokenContract.transfer(owner, tokenContract.balanceOf(address(this))), "Transfer failed");

        // Transfer the balance to the owner
        payable(owner).transfer(address(this).balance);
    }

    receive() external payable {
    revert("Do not send Ether directly");
}

    function transferOwnership(address newOwner) public onlyOwner  {
        require(newOwner != address(0), "New owner is the zero address");
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }
}

