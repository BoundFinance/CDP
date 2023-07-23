pragma solidity ^0.8.18;

contract EthPool {
    address payable public  owner;
    address public tub;

    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    modifier onlyTub() {
        require(msg.sender == tub);
        _;
    }

    constructor(address _tub) public {
        owner = payable(msg.sender);
        tub = _tub;
    }

    function deposit() public payable  {}

    function withdraw(uint256 amount) public onlyOwner {
        require(address(this).balance >= amount);
        owner.transfer(amount);
    }

    function payInterest(address recipient, uint256 amount) public onlyTub {
        require(address(this).balance >= amount);
        payable(recipient).transfer(amount);
    }

    function transferOwnership(address payable newOwner) public onlyOwner {
        require(newOwner != address(0));
        owner = newOwner;
    }
}

