// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "erc20/erc20.sol";
import "./tub.sol";
import "./tap.sol";

contract BundleContract {
    SaiTub public tub;
    SaiTap public tap;
    ERC20 public skrToken;
    ERC20 public saiToken;
    ERC20 public bckethToken;
    address public owner;

    constructor(address _bckethTokenAddress) {
        bckethToken = ERC20(_bckethTokenAddress);
        owner = msg.sender;
    }

    // Sets the Tub contract address
    function setTubandSKR(address _tubAddress, address _skrTokenAddress, address _saiTokenAddress, address _tapaddress) public {
        require(msg.sender == owner, "Only the owner can set the Tub contract");
        tub = SaiTub(_tubAddress);
        skrToken = ERC20(_skrTokenAddress);
        saiToken = ERC20(_saiTokenAddress);
        tap = SaiTap(_tapaddress);
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

    function bustAndExit(uint wad) public {
    require(address(tub) != address(0), "Tub contract has not been set");
    require(address(skrToken) != address(0), "SKR token has not been set");
    require(address(tap) != address(0), "Tap contract has not been set");
    
    uint woeamount = tap.woe();  // Assume woe() is a method that fetches woe amount
    uint fogamount = tap.fog();  // Assume fog() is a method that fetches fog amount
    
    require(!(woeamount == 0 && fogamount == 0), "No BCK debt and no collateral is available for liquidation.");
    
    uint amountToApprove = wad;
    uint minBCKRequired = tap.ask(fogamount);
    
    if (fogamount > 0 && woeamount == 0) {
        if (wad > minBCKRequired) {
            amountToApprove = minBCKRequired;
        }
    } else if (wad > woeamount) {
        amountToApprove = woeamount;
    }
    
    require(saiToken.transferFrom(msg.sender, address(this), amountToApprove), "Transfer of BCK tokens failed");
    require(saiToken.approve(address(tap), amountToApprove), "Approval of BCK tokens failed");

    // Calculations for amount to bust, similar to your Web3 code
    uint saitoSKR = tap.s2s();
    uint amountToBust = amountToApprove / saitoSKR;

    tap.bust(amountToBust); 
     // Assume bust() is a method that buys the liquidated collateral
    uint actualwad = tub.bid(amountToBust);
    require(skrToken.approve(address(tub), amountToBust), "SKR Approval failed");

    tub.exit(amountToBust);  // Assume exit() is a method that exits the liquidated collateral
    require(bckethToken.transfer(msg.sender, actualwad), "Transfer failed");

}

}

