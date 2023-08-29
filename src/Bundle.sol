// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "erc20/erc20.sol";
import "./tub.sol";

contract BundleContract {
    SaiTub public tub;
    ERC20 public skrToken;
    ERC20 public bckethToken;
    address public owner;

    constructor(address _bckethTokenAddress) {
        bckethToken = ERC20(_bckethTokenAddress);
        owner = msg.sender;
    }

    // Sets the Tub contract address
    function setTubandSKR(address _tubAddress, address _skrTokenAddress) public {
        require(msg.sender == owner, "Only the owner can set the Tub contract");
        tub = SaiTub(_tubAddress);
        skrToken = ERC20(_skrTokenAddress);
    }


    function joinAndLock(bytes32 cup, uint wad) public {
        require(address(tub) != address(0), "Tub contract has not been set");
        require(address(skrToken) != address(0), "SKR token has not been set");

        uint actualwad = tub.ask(wad);
        
        require(bckethToken.transferFrom(msg.sender, address(this), actualwad), "Transfer failed");
        require(bckethToken.approve(address(tub), actualwad), "Approval failed");

        tub.join(wad);
        require(skrToken.approve(address(tub), actualwad), "SKR Approval failed");
        tub.lock(cup, actualwad);
    }

    function freeAndExit(bytes32 cup, uint wad) public {
        require(address(tub) != address(0), "Tub contract has not been set");
        require(address(skrToken) != address(0), "SKR token has not been set");
        require(msg.sender == tub.lad(cup), "Unauthorized: You are not the lad of this cup");

        tub.free(cup, wad);
        uint actualwad = tub.bid(wad);
        
        require(skrToken.approve(address(tub), wad), "SKR Approval failed");
        tub.exit(wad);
        
        require(bckethToken.transfer(msg.sender, actualwad), "Transfer failed");
    }
}

