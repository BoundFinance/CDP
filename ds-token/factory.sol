pragma solidity ^0.8.13;

import "./token.sol";

contract DSTokenFactory {
    event LogMake(address indexed owner, address token);

    function make(
        string memory symbol, string memory name
    ) public returns (DSToken result) {
        result = new DSToken(symbol);
        result.setName(name);
        result.setOwner(msg.sender);
       emit LogMake(msg.sender, address(result));
    }
}
