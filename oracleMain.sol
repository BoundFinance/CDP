//SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

// Interface for the UniswapV3Twap contract
interface IUniswapV3Twap {
    function estimateAmountOut(address tokenIn, uint128 amountIn, uint32 secondsAgo) external view returns (uint amountOut);
    function token0() external view returns (address);
}

// Interface for the TestChainlink contract
interface ITestChainlink {
    function getLatestPrice() external view returns (int);
}

// Interface for the DSValue contract
interface IDSValue {
    function poke(bytes32 wut) external;
}

contract TokenPriceInUSD {
    IUniswapV3Twap public uniswapTwap;
    ITestChainlink public chainlinkOracle;
    IDSValue public dsValue; // reference to the DSValue contract
    address public owner;
    uint128 public defaultAmountIn = 1 ether;
    uint32 public defaultSecondsAgo = 5;

    constructor(address _uniswapTwap, address _chainlinkOracle, address _dsValue) {
        uniswapTwap = IUniswapV3Twap(_uniswapTwap);
        chainlinkOracle = ITestChainlink(_chainlinkOracle);
        dsValue = IDSValue(_dsValue); // initialize DSValue reference
        owner = msg.sender;
    }

       modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    function setDefaults(uint128 newAmountIn, uint32 newSecondsAgo) external onlyOwner {
        defaultAmountIn = newAmountIn;
        defaultSecondsAgo = newSecondsAgo;
    }

    function getBCKETHPriceInUSD(uint128 amountIn, uint32 secondsAgo) public view returns (bytes32) {
        // Step 1: Fetch BCKETH price in ETH (wad format)
        uint bckethInEth = uniswapTwap.estimateAmountOut(uniswapTwap.token0(), amountIn, secondsAgo);

        // Step 2: Fetch ETH price in USD (normal dollar format)
        int ethPriceInUsd = chainlinkOracle.getLatestPrice();

        // Ensure the price is not negative (This is a basic sanity check, you might want to handle more cases)
        require(ethPriceInUsd > 0, "Invalid ETH price");

        // Step 3: Convert BCKETH price to USD (wad format)
        uint bckethInUsd = bckethInEth * uint(ethPriceInUsd);
        
        // Convert to bytes32
        bytes32 bckethPriceInBytes = bytes32(bckethInUsd);
        
        return bckethPriceInBytes;
    }

      function updateDSValuePrice() external returns (bytes32) {
        bytes32 priceInBytes = getBCKETHPriceInUSD(defaultAmountIn, defaultSecondsAgo);

        // Fetch the latest Chainlink ETH price in USD
        int latestChainlinkPrice = chainlinkOracle.getLatestPrice();
        require(latestChainlinkPrice > 0, "Invalid Chainlink ETH price");

        // Convert the bytes32 price back to uint for comparison
        uint bckethInUsd = uint(priceInBytes);

        // Check if the bckethInUsd is less than 75% of the Chainlink ETH price in USD
        if (bckethInUsd < (uint(latestChainlinkPrice) * 75) / 100) {
            // Revert to Chainlink ETH price in USD if the condition is not met
            priceInBytes = bytes32(uint(latestChainlinkPrice));
        }

        // Update the DSValue with the new price
        dsValue.poke(priceInBytes);

        return priceInBytes;
    }

}

