/// tap.sol -- liquidation engine (see also `vow`)

// Copyright (C) 2017  Nikolai Mushegian <nikolai@dapphub.com>
// Copyright (C) 2017  Daniel Brockman <daniel@dapphub.com>
// Copyright (C) 2017  Rain Break <rainbreak@riseup.net>

// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.

// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.

// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.

pragma solidity ^0.8.18;

import "./tub.sol";

contract SaiTap is DSThing {
    DSToken  public  sai;
    DSToken  public  sin;
    DSToken  public  skr;

    SaiVox   public  vox;
    SaiTub   public  tub;

    uint256  public  gap;  // Boom-Bust Spread
    bool     public  off;  // Cage flag
    uint256  public  fix;  // Cage price

event AskResult(uint result);
event S2SResult(uint result);
event bidResult(uint result);

    // Surplus
    function joy() public view returns (uint) {
        return sai.balanceOf(address(this));
    }
    // Bad debt
    function woe() public view returns (uint) {
        return sin.balanceOf(address(this));
    }
    // Collateral pending liquidation
    function fog() public view returns (uint) {
        return skr.balanceOf(address(this));
    }


    constructor (SaiTub tub_) public {
        tub = tub_;

        sai = tub.sai();
        sin = tub.sin();
        skr = tub.skr();

        vox = tub.vox();

        gap = WAD;
    }

    function mold(bytes32 param, uint val) public payable note auth {
        if (param == 'gap') gap = val;
    }

    // Cancel debt
    function heal() public payable note {
        if (joy() == 0 || woe() == 0) return;  // optimised
        uint wad = min(joy(), woe());
        sai.burn(wad);
        sin.burn(wad);
    }

    // Feed price (sai per skr)
    function s2s() public  returns (uint) {
        uint tag = tub.tag();    // ref per skr
        uint par = vox.par(); 
        uint result = rdiv(tag, par);
        emit  S2SResult(result); // ref per sai
        return result;  // sai per skr
    }
    // Boom price (sai per skr)
    function bid(uint wad) public returns (uint) {
        uint result = rmul(wad, wmul(s2s(), sub(2 * WAD, gap)));
        emit bidResult(result);
        return result;
    }
    // Bust price (sai per skr)
    function ask(uint wad) public returns (uint) {
        uint result = rmul(wad, wmul(s2s(), gap));
        emit AskResult(result);
        return result;
    }
    function flip(uint wad, address user) internal {
        require(ask(wad) > 0, "(ask) > 0 was not satisfied" );
        skr.transferFrom(address(this), user, wad);
        sai.transferFrom(user, address(this), ask(wad));
        heal();
    }
    function flop(uint wad, address user) internal {
        skr.mint(sub(wad, fog()));
        flip(wad, user);
        require(joy() == 0);  // can't flop into surplus
    }
    function flap(uint wad, address user) internal {
        heal();
        sai.transferFrom(address(this), user, wad);
        skr.burn(user, wad);
    }
    function bust(uint wad) public payable note {
        require(!off, "off is the issue");
        address user = msg.sender;

        if (wad > fog()) flop(wad, user);
        else flip(wad, user);
    }
    function boom(uint wad) public payable note {
        require(!off);
        address user = msg.sender;
        flap(wad, user);
    }

    //------------------------------------------------------------------

    function cage(uint fix_) public payable note auth {
        require(!off);
        off = true;
        fix = fix_;
    }
    function cash(uint wad) public payable note {
        require(off);
        sai.burn(msg.sender, wad);
        require(tub.gem().transfer(msg.sender, rmul(wad, fix)));
    }
    function mock(uint wad) public payable note {
        require(off);
        sai.mint(msg.sender, wad);
        require(tub.gem().transferFrom(msg.sender, address(this), rmul(wad, fix)));
    }
    function vent() public payable note {
        require(off);
        skr.burn(fog());
    }
}
