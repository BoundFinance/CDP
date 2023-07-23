/// value.sol - a value is a simple thing, it can be get and set

// Copyright (C) 2017  DappHub, LLC

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

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import 'ds-thing/thing.sol';

contract DSValue is DSThing {
    bool    has;
    bytes32 val;
    function peek() public view returns (bytes32, bool) {
        return (val,has);
    }
    function read() public view returns (bytes32) {
        (bytes32 wut, bool haz) = peek(); // change var to actual types
        require(haz, "DSValue: invalid value"); // change assert to require and add a revert message
        return wut;
    }
    function poke(bytes32 wut) public note payable auth {
        val = wut;
        has = true;
    }
    function void() public note payable auth {  // unset the value
        has = false;
    }
}
//0x0cd070a5516d934336eD59a1646Cc0a3819046b7