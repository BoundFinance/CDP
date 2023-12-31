/// tub.sol -- simplified CDP engine (baby brother of `vat')

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

import "ds-thing/thing.sol";
import "ds-token/token.sol";
import "ds-value/value.sol";
import "SafeMathUint.sol";
import "SafeMathInt.sol";

import "./vox.sol";
import "./EthPool.sol";

contract SaiTubEvents {
    event LogNewCup(address indexed lad, bytes32 cup);
}

contract SaiTub is DSThing, SaiTubEvents {
    DSToken  public  sai;  // Stablecoin
    DSToken  public  sin;  // Debt (negative sai)

    DSToken  public  skr;  // Abstracted collateral
    ERC20    public  gem;  // Underlying collateral

    DSToken  public  gov;  // Governance token

    SaiVox   public  vox;  // Target price feed
    DSValue  public  pip;  // Reference price feed
    DSValue  public  pep;  // Governance price feed

    address  public  tap;  // Liquidator
    address  public  pit;  // Governance Vault

    uint256  public  axe;  // Liquidation penalty
    uint256  public  cap;  // Debt ceiling
    uint256  public  mat;  // Liquidation ratio
    uint256  public  tax;  // Stability fee
    uint256  public  fee;  // Governance fee
    uint256  public  gap;  // Join-Exit Spread

    bool     public  off;  // Cage flag
    bool     public  out;  // Post cage exit

    uint256  public  fit;  // REF per SKR (just before settlement)

    uint256  public  rho;  // Time of last drip
    uint256         _chi;  // Accumulated Tax Rates
    uint256         _rhi;  // Accumulated Tax + Fee Rates
    uint256  public  rum;  // Total normalised debt
    uint256 public interestDistributedAcross;

    uint256 public  cupi;
    mapping (bytes32 => Cup)  public  cups;
    
    uint256 public earnRatio; // Collateral-to-debt ratio for earning interest
    uint256 public withdrawInterval;

   // Interest rate
    uint256 public interestWithdrawalCooldown; // Cooldown period for interest withdrawal (in seconds)
    using SafeMathUint for uint256;
    using SafeMathInt for int256;

    uint256 constant internal magnitude = 2**128;
    uint256 internal magnifiedInterestPerShare;
    uint256 public totalCollateral;
    address public authorizedCaller;


    mapping(bytes32 => int256) internal magnifiedInterestCorrections;
    mapping(bytes32 => uint256) internal withdrawnInterest;

    event InterestDistributed(uint256 value);
    event InterestWithdrawn(address indexed from, uint256 value);

   
    uint256 public interestRateThreshold = (45 * RAY) / 10;

    EthPool public ethPool;

    struct Cup {
        address  lad;      // CDP owner
        uint256  ink;      // Locked collateral (in SKR)
        uint256  art;      // Outstanding normalised debt (tax only)
        uint256  ire;      // Outstanding normalised debt
        uint256 lastWithdraw; // Timestamp of the last interest withdrawal
        uint256 userInterest; 
        uint256 lastSchi;
    }

    struct InterestRateChange {
        uint rate;
        uint blockTimestamp; 
    }

    function lad(bytes32 cup) public view returns (address) {
        return cups[cup].lad;
    }
    function ink(bytes32 cup) public view returns (uint) {
        return cups[cup].ink;
    }
    function tab(bytes32 cup) public returns (uint) {
        return rmul(cups[cup].art, chi());
    }
    function rap(bytes32 cup) public returns (uint) {
        return sub(rmul(cups[cup].ire, rhi()), tab(cup));
    }

    // Total CDP Debt
    function din() public returns (uint) {
        return rmul(rum, chi());
    }
    // Backing collateral
    function air() public view returns (uint) {
        return skr.balanceOf(address(this));
    }
    // Raw collateral
    function pie() public view returns (uint) {
        return gem.balanceOf(address(this));
    }

    //------------------------------------------------------------------

     constructor(
        DSToken  sai_,
        DSToken  sin_,
        DSToken  skr_,
        ERC20    gem_,
        DSToken  gov_,
        DSValue  pip_,
        DSValue  pep_,
        SaiVox   vox_,
        address  pit_,
        address _approvedcaller
    
    ) public {
        gem = gem_;
        skr = skr_;

        sai = sai_;
        sin = sin_;

        gov = gov_;
        pit = pit_;

        pip = pip_;
        pep = pep_;
        vox = vox_;

        axe = RAY;
        mat = RAY;
        tax = RAY;
        fee = RAY;
        gap = WAD;

        _chi = RAY;
        _rhi = RAY;
        interestWithdrawalCooldown = 1 days;
        rho = era();
        authorizedCaller = _approvedcaller;
    }

    function era() public returns (uint) {
        return block.timestamp;
    }

    //--Risk-parameter-config-------------------------------------------

    function mold(bytes32 param, uint val) public payable note auth {
        if      (param == 'cap') cap = val;
        else if (param == 'mat') { require(val >= RAY); mat = val; }
        else if (param == 'tax') { require(val >= RAY); drip(); tax = val; }
        else if (param == 'fee') { require(val >= RAY); drip(); fee = val; }
        else if (param == 'axe') { require(val >= RAY); axe = val; }
        else if (param == 'gap') { require(val >= WAD); gap = val; }
        else return;
    }

    //--Price-feed-setters----------------------------------------------

    function setPip(DSValue pip_) public payable note auth {
        pip = pip_;
    }
    function setPep(DSValue pep_) public payable note auth {
        pep = pep_;
    }
    function setVox(SaiVox vox_) public payable note auth {
        vox = vox_;
    }

    //--Tap-setter------------------------------------------------------
    function turn(address tap_) public payable note {
        require(tap  == address(0));
        require(tap_ != address(0));
        tap = tap_;
    }

    //--Collateral-wrapper----------------------------------------------

    // Wrapper ratio (gem per skr)
    function per() public view returns (uint ray) {
        return skr.totalSupply() == 0 ? RAY : rdiv(pie(), skr.totalSupply());
    }
    // Join price (gem per skr)
    function ask(uint wad) public view returns (uint) {
        return rmul(wad, wmul(per(), gap));
    }
    // Exit price (gem per skr)
    function bid(uint wad) public view returns (uint) {
        return rmul(wad, wmul(per(), sub(2 * WAD, gap)));
    }
    function join(uint wad) public payable note {
        require(!off);
        require(ask(wad) > 0);
        require(gem.transferFrom(msg.sender, address(this), ask(wad)));
        skr.mint(msg.sender, wad);
    }
    function exit(uint wad) public payable note {
        require(!off || out);
        require(gem.transfer(msg.sender, bid(wad)));
        skr.burn(msg.sender, wad);
    }

    //--Stability-fee-accumulation--------------------------------------

    // Accumulated Rates
    function chi() public returns (uint) {
        drip();
        return _chi;
    }
    function rhi() public returns (uint) {
        drip();
        return _rhi;
    }
    function drip() public payable note {
        if (off) return;

        uint rho_ = era();
        uint age = rho_ - rho;
        if (age == 0) return;    // optimised
        rho = rho_;

        uint inc = RAY;

        if (tax != RAY) {  // optimised
            uint _chi_ = _chi;
            inc = rpow(tax, age);
            _chi = rmul(_chi, inc);
            sai.mint(tap, rmul(sub(_chi, _chi_), rum));
        }

        // optimised
        if (fee != RAY) inc = rmul(inc, rpow(fee, age));
        if (inc != RAY) _rhi = rmul(_rhi, inc);
    }


    //--CDP-risk-indicator----------------------------------------------

    // Abstracted collateral price (ref per skr)
    function tag() public view returns (uint wad) {
        return off ? fit : wmul(per(), uint(pip.read()));
    }
    // Returns true if cup is well-collateralized
    function safe(bytes32 cup) public returns (bool) {
        uint pro = rmul(tag(), ink(cup));
        uint con = rmul(vox.par(), tab(cup));
        uint min = rmul(con, mat);
        return pro >= min;
    }


    //--CDP-operations--------------------------------------------------

    function open() public payable note returns (bytes32 cup) {
        require(!off);
        cupi = add(cupi, 1);
        cup = bytes32(cupi);
        cups[cup].lad = msg.sender;
        emit LogNewCup(msg.sender, cup);
    }


    function lock(bytes32 cup, uint wad) public payable note {
        require(!off);
            totalCollateral = add(totalCollateral, wad);  // decrease total collateral
        magnifiedInterestCorrections[cup] = magnifiedInterestCorrections[cup]
            .sub( (magnifiedInterestPerShare.mul(wad)).toInt256Safe() );
        cups[cup].ink = add(cups[cup].ink, wad);
        skr.transferFrom(msg.sender, address(this), wad);
        require(cups[cup].ink == 0 || cups[cup].ink > 0.005 ether);

    }
    function free(bytes32 cup, uint wad) public payable note {
        require(msg.sender == cups[cup].lad || msg.sender == authorizedCaller);
            totalCollateral = sub(totalCollateral, wad);  // decrease total collateral
        magnifiedInterestCorrections[cup] = magnifiedInterestCorrections[cup]
            .add( (magnifiedInterestPerShare.mul(wad)).toInt256Safe() );
        cups[cup].ink = sub(cups[cup].ink, wad);
        skr.transferFrom(address(this),msg.sender, wad);
        require(safe(cup));
        require(cups[cup].ink == 0 || cups[cup].ink > 0.005 ether); 

    }

    function draw(bytes32 cup, uint wad) public payable note {
        require(!off);
        require(msg.sender == cups[cup].lad);
        require(rdiv(wad, chi()) > 0);
       

        cups[cup].art = add(cups[cup].art, rdiv(wad, chi()));
        rum = add(rum, rdiv(wad, chi()));

        cups[cup].ire = add(cups[cup].ire, rdiv(wad, rhi()));
        sai.mint(cups[cup].lad, wad);
   
        require(safe(cup));
        require(sai.totalSupply() <= cap);
        

    }
    function wipe(bytes32 cup, uint wad) public payable note {
        require(!off);
        

        uint owe = rmul(wad, rdiv(rap(cup), tab(cup)));

        cups[cup].art = sub(cups[cup].art, rdiv(wad, chi()));
        rum = sub(rum, rdiv(wad, chi()));

        cups[cup].ire = sub(cups[cup].ire, rdiv(add(wad, owe), rhi()));
        sai.burn(msg.sender, wad);
        (bytes32 val, bool ok) = pep.peek();
if (ok && uint(val) != 0) {
    gov.move(msg.sender, pit, wdiv(owe, uint(val)));
    }
}


function bite(bytes32 cup) public payable note {
    require(!safe(cup) || off);

    // Take on all of the debt, except unpaid fees
    uint rue = tab(cup);
    sin.mint(tap, rue);
    rum = sub(rum, cups[cup].art);
    cups[cup].art = 0;
    cups[cup].ire = 0;

    // Amount owed in SKR, including liquidation penalty
    uint owe = rdiv(rmul(rmul(rue, axe), vox.par()), tag());

    if (owe > cups[cup].ink) {
        owe = cups[cup].ink;
    }

    uint shareofowe = rmul(owe, axe);
    uint reducedOwe = sub(owe, shareofowe);

    // The penalty will be divided between the protocol and the caller
    uint penaltyForCaller = shareofowe / 2;
    uint penaltyForProtocol = shareofowe - penaltyForCaller;

    skr.push(tap, reducedOwe);
    totalCollateral = sub(totalCollateral, reducedOwe);  // decrease total collateral
    cups[cup].ink = sub(cups[cup].ink, reducedOwe);
    //--------------- Send the Liquidation penalty to the user ----------------------//
    if(msg.sender == cups[cup].lad) {
    exit(shareofowe); // exits and burns SKR tokens for the entire penalty
    gem.transfer(address(owner), bid(shareofowe)); // transfers equivalent gem tokens to owner
} else {
    exit(penaltyForCaller); // exits and burns SKR tokens for the caller's share
    gem.transfer(msg.sender, bid(penaltyForCaller)); // transfers equivalent gem tokens to caller

    exit(penaltyForProtocol); // exits and burns SKR tokens for the protocol's share
    gem.transfer(address(owner), bid(penaltyForProtocol)); // transfers equivalent gem tokens to owner
}

    // Update interest tracking for the cup
    if (cups[cup].ink == 0) {
        // If all collateral has been liquidated, reset interest tracking for the cup
        magnifiedInterestCorrections[cup] = 0;
        withdrawnInterest[cup] = 0;
    } else {
        // If some collateral remains, correct the tracking amount so it reflects the new collateral amount
        magnifiedInterestCorrections[cup] = magnifiedInterestPerShare.mul(cups[cup].ink).toInt256Safe();
    }
}


    //----------------------- CDP Earn Interest ------------------------
   
function setEthPool(EthPool ethPool_) public payable note auth {
    ethPool = ethPool_;
}

function setWithdrawCooldown(uint256 cooldown) public payable note auth {
    interestWithdrawalCooldown = cooldown;
}

function setInterestRateRatioThreshold(uint256 threshold) public auth {
    interestRateThreshold = threshold * RAY / 10;
}


 function distributeRewards() public payable {
        require(msg.value > 0);
        require(totalCollateral > 0);
        
        magnifiedInterestPerShare = magnifiedInterestPerShare.add(
            (msg.value).mul(magnitude) / totalCollateral
        );

        interestDistributedAcross += msg.value;

        emit InterestDistributed(msg.value);
        ethPool.deposit{value: msg.value}();
         
    }


    function withdrawInterest(bytes32 cup) public {
        require(msg.sender == cups[cup].lad);
        require(cups[cup].ink != 0, "ink is 0");
        require(cups[cup].art != 0, "art is 0");
        require(safe(cup), "cup is not safe");
        require(block.timestamp >= cups[cup].lastWithdraw + interestWithdrawalCooldown, "You need to wait longer");

        uint256 _withdrawableInterest = withdrawableEthInterestOf(cup);
        if (_withdrawableInterest > 0) {
            withdrawnInterest[cup] = withdrawnInterest[cup].add(_withdrawableInterest);
            emit InterestWithdrawn(msg.sender, _withdrawableInterest);
            ethPool.payInterest(msg.sender, _withdrawableInterest);
        }
    }

    function getUserDebt(bytes32 cup) public view returns (uint) {
      return cups[cup].art;
    }

    function interestOf(bytes32 cup) public view returns(uint256) {
        return withdrawableEthInterestOf(cup);
    }

    function withdrawableEthInterestOf(bytes32 cup) public view returns(uint256) {
        return accumulativeEthInterestOf(cup).sub(withdrawnInterest[cup]);
    }

    function withdrawnInterestOf(bytes32 cup) public view returns(uint256) {
        return withdrawnInterest[cup];
    }

    function accumulativeEthInterestOf(bytes32 cup) public view returns(uint256) {
        return magnifiedInterestPerShare.mul(cups[cup].ink).toInt256Safe()
            .add(magnifiedInterestCorrections[cup]).toUint256Safe() / magnitude;
    }


//------------------------------------------------------------------

    function cage(uint fit_, uint jam) public payable note auth {
        require(!off && fit_ != 0);
        off = true;
        axe = RAY;
        gap = WAD;
        fit = fit_;         // ref per skr
        require(gem.transfer(tap, jam));
        require(axe == RAY, "axe does not equal to RAY ");
    }
    function flow() public payable note auth {
        require(off);
        out = true;
    }
}


