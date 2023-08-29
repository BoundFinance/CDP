// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IERC20Token {
    function balanceOf(address owner) external returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function decimals() external returns (uint8);
}

contract TokenSale {
    IERC20Token public tokenContract;  // the token being sold
    uint256 public price;              // the price, in wei, per token
    address public owner;
    uint256 public tokensSold;

    event Sold(address indexed buyer, uint256 amount);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    modifier onlyOwner() {
        require(msg.sender == owner, "You are not the owner");
        _;
    }

    bool private reentrancyGuard = false;

    modifier nonReentrant() {
        require(!reentrancyGuard, "Reentrant call");
        reentrancyGuard = true;
        _;
        reentrancyGuard = false;
    }

    constructor(IERC20Token _tokenContract, uint256 _price) {
        owner = msg.sender;
        tokenContract = _tokenContract;
        price = _price;
    }

    function buyTokens(uint256 numberOfTokens) public payable  {
        require(msg.value == numberOfTokens * price, "Mismatched value sent");

        uint256 scaledAmount = numberOfTokens * (10 ** uint256(tokenContract.decimals()));

        require(tokenContract.balanceOf(address(this)) >= scaledAmount, "Insufficient tokens");

        tokensSold += numberOfTokens;

        emit Sold(msg.sender, numberOfTokens);

        require(tokenContract.transfer(msg.sender, scaledAmount), "Token transfer failed");
    }

    function endSale() public onlyOwner  {
        // Send unsold tokens to the owner.
        require(tokenContract.transfer(owner, tokenContract.balanceOf(address(this))), "Transfer failed");

        // Transfer the balance to the owner
        payable(owner).transfer(address(this).balance);
    }

    function transferOwnership(address newOwner) public onlyOwner {
        require(newOwner != address(0), "New owner is the zero address");
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }
}

