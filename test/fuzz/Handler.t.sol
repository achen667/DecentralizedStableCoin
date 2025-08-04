// // SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {Test} from "forge-std/Test.sol";
// import { ERC20Mock } from "@openzeppelin/contracts/mocks/ERC20Mock.sol"; Updated mock location
import {ERC20Mock} from "../mocks/ERC20Mock.sol";

import {MockV3Aggregator} from "../mocks/MockV3Aggregator.sol";
import {DSCEngine, AggregatorV3Interface} from "../../src/DSCEngine.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
// import {Randomish, EnumerableSet} from "../Randomish.sol"; // Randomish is not found in the codebase, EnumerableSet
// is imported from openzeppelin
import {console} from "forge-std/console.sol";

contract Handler is Test {
    DSCEngine public dscEngine;
    DecentralizedStableCoin public dsc;

    // address public ethUsdPriceFeed;
    // address public btcUsdPriceFeed;
    ERC20Mock public weth;
    ERC20Mock public wbtc;

    address public USER = makeAddr("user");
    uint96 public constant COLLATERAL_AMOUNT_MAX = type(uint96).max;

    uint256 public timesMintIsCalled = 0;

    constructor(DSCEngine _dscEngine, DecentralizedStableCoin _dsc) {
        dscEngine = _dscEngine;
        dsc = _dsc;

        address[] memory collateralTokens = dscEngine.getCollateralTokens();
        weth = ERC20Mock(collateralTokens[0]);
        wbtc = ERC20Mock(collateralTokens[1]);
        console.log("weth address:", address(weth));
        console.log("wbtc address:", address(wbtc));
    }

    function mintDSC(uint256 amount) public {
        (uint256 totalDscMinted, uint256 collateralValueInUsd) = dscEngine.getAccountInformation(USER);
        int256 maxDscToMint = (int256(collateralValueInUsd) / 2) - int256(totalDscMinted);
        // console.log("collateralValueInUsd / 2:", collateralValueInUsd / 2);
        // console.log("totalDscMinted:", totalDscMinted);
        if (maxDscToMint < 0) {
            return;
        }
        amount = bound(amount, 0, uint256(maxDscToMint));
        if (amount == 0) {
            return;
        }
        vm.startPrank(USER);
        dscEngine.mintDSC(amount);
        vm.stopPrank();

        timesMintIsCalled++;
    }

    function depositCollateral(uint256 collateralSeed, uint256 collateralAmount) public {
        ERC20Mock collateralToken = _getCollateralFromSeed(collateralSeed);
        console.log("token:", address(collateralToken));
        collateralAmount = bound(collateralAmount, 1, COLLATERAL_AMOUNT_MAX);

        vm.startPrank(USER);
        collateralToken.mint(USER, collateralAmount);
        collateralToken.approve(address(dscEngine), collateralAmount);

        dscEngine.depositCollateral(address(collateralToken), collateralAmount);
        vm.stopPrank();
    }

    //This function may revert for breaking the health factor
    function redeemCollateral(uint256 collateralSeed, uint256 collateralAmount) public {
        ERC20Mock collateralToken = _getCollateralFromSeed(collateralSeed);
        //console.log("token:",address(collateralToken));

        // (uint256 totalDscMinted, uint256 collateralValueInUsd) = dscEngine.getAccountInformation(USER);
        // uint256 userCollateralBalance = dscEngine.getCollateralBalanceOfUser(USER, address(collateralToken));
        // uint256 maxCollateralToRedeem = userCollateralBalance * 2000 - totalDscMinted * 2 ;
        uint256 maxCollateralToRedeem = dscEngine.getCollateralBalanceOfUser(USER, address(collateralToken));
        //console.log("maxCollateralToRedeem:",maxCollateralToRedeem);
        collateralAmount = bound(collateralAmount, 0, maxCollateralToRedeem / 2); //if 1000dsc/2000usd collateral,then can redeem 0
        if (collateralAmount == 0) {
            return;
        }
        vm.startPrank(USER);
        dscEngine.redeemCollateral(address(collateralToken), collateralAmount);
        vm.stopPrank();
    }

    function liquidate(uint256 collateralSeed, address userToBeLiquidated, uint256 debtToCover) public {
        ERC20Mock collateral = _getCollateralFromSeed(collateralSeed);
        dscEngine.liquidate(address(collateral), userToBeLiquidated, debtToCover);
    }

    function _getCollateralFromSeed(uint256 collateralSeed) internal view returns (ERC20Mock) {
        if (collateralSeed % 2 == 0) {
            return weth;
        }
        return wbtc;
    }
}
