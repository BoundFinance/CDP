/// vox.sol -- target price feed

// Copyright (C) 2016, 2017  Nikolai Mushegian <nikolai@dapphub.com>
// Copyright (C) 2016, 2017  Daniel Brockman <daniel@dapphub.com>
// Copyright (C) 2017        Rain Break <rainbreak@riseup.net>

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

import "ds-thing/thing.sol";
import "SafeMathInt.sol";

contract SaiVox is DSThing {
    using SafeMathInt for int256;

    uint256  _par;
    uint256  _way;

    uint256  public  fix;
    uint256  public  how;
    uint256  public  tau;

    event Parresult(uint Par1);

    constructor(uint par_) public {
        _par = fix = par_;
        _way = RAY;
        tau  = era();
    }

    function era() public view returns (uint) {
        return block.timestamp;
    }

    function mold(bytes32 param, uint val) public payable note auth {
        if (param == 'way') _way = val;
    }

    // Dai Target Price (ref per dai)
    function par() public returns (uint) {
        prod();
        uint Par1 = _par;
        return Par1;
    }
    function way() public returns (uint) {
        prod();
        return _way;
    }

    function tell(uint256 ray) public payable  note auth {
        fix = ray;
    }
    function tune(uint256 ray) public payable note auth {
        how = ray;
    }

    function prod() public payable  note {
        uint age = era() - (tau);
        if (age == 0) return;  // optimised
        tau = era();

        if (_way != RAY) _par = rmul(_par, rpow(_way, age));  // optimised

        if (how == 0) return;  // optimised
        int256 wag = int256(how * (age));
        _way = inj(prj(_way).add(fix < _par ? wag : wag.mul(-1)));
    }

    function inj(int256 x) internal pure returns (uint256) {
        return x >= 0 ? uint256(x) + RAY
            : rdiv(RAY, RAY + uint256(x.mul(-1)));
    }
    function prj(uint256 x) internal pure returns (int256) {
        return x >= RAY ? int256(x - RAY)
            : int256(RAY).sub(int256(rdiv(RAY, x)));
    }
}
