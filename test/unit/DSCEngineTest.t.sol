// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {DeployDSC} from "../../script/DeployDSC.s.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
// import { ERC20Mock } from "@openzeppelin/contracts/mocks/ERC20Mock.sol"; Updated mock location
import {ERC20Mock} from "../mocks/ERC20Mock.sol";
import {MockV3Aggregator} from "../mocks/MockV3Aggregator.sol";

import {Test, console} from "forge-std/Test.sol";

contract DSCEngineTest is Test {
    DecentralizedStableCoin public dsc;
    DSCEngine public dscEngine;
    HelperConfig public config;
    DeployDSC public deployer;

    address wethPriceFeed;
    address weth;

    address public USER = makeAddr("user");
    address public LIQUIDATOR = makeAddr("liquidator");
    uint256 public constant AMOUNT_COLLATERAL = 11 ether; //22000 usd
    uint256 public constant STARTING_ERC20_BALANCE = 11 ether; //collateral
    uint256 public constant AMOUNT_MINT = 10000 ether; //10000usd
    uint256 public constant ETH_PRICE = 2000; //usd
    uint256 public constant LIQUIDATION_THRESHOLD = 50;
    uint256 public constant LIQUIDATION_BONUS = 10;
    uint256 public constant LIQUIDATION_PRECISION = 100;

    function setUp() public {
        deployer = new DeployDSC();
        (dsc, dscEngine, config) = deployer.run();
        (wethPriceFeed,, weth,,) = config.activeNetworkConfig();
        ERC20Mock(weth).mint(USER, STARTING_ERC20_BALANCE);
    }

    //////////////////////////
    //  Price Tests         //
    //////////////////////////
    function testGetUsdValue() public view {
        uint256 price = dscEngine.getUsdValue(weth, 15e18);
        uint256 expectedValue = 30000e18; //weth price:2000e8
        console.log("price", price);
        console.log("expect", expectedValue);
        assert(price == expectedValue);
    }

    //////////////////////////
    //  Collateral Tests    //
    //////////////////////////

    modifier depositWethAndMint(uint256 amountCollateral, uint256 amountMint) {
        vm.startPrank(USER);
        //vm.prank(USER);
        ERC20Mock(weth).approve(address(dscEngine), amountCollateral);
        dscEngine.depositCollateralAndMintDSC(weth, amountCollateral, amountMint);
        vm.stopPrank();
        _;
    }

    function testDepositCollateralAmountNeedMoreThanZero() public {
        vm.prank(USER);
        //ERC20Mock(weth).approve(address(dscEngine),AMOUNT_COLLATERAL);

        vm.expectRevert(DSCEngine.DSCEngine__NeedsMoreThanZero.selector);
        dscEngine.depositCollateral(weth, 0);
        vm.stopPrank();
    }

    function testDeposiCollateralAndMint() public depositWethAndMint(AMOUNT_COLLATERAL, AMOUNT_MINT) {
        uint256 expectDscAmount = 10000e18;
        uint256 expectCollateralValue = 22000e18;

        (uint256 totalDscMInted, uint256 collateralValueInUSD) = dscEngine.getAccountInformation(USER);
        // console.log("totalDscMInted:",totalDscMInted);
        // console.log("collateralValueInUSD:",collateralValueInUSD);
        assertEq(expectDscAmount, totalDscMInted);
        assertEq(expectCollateralValue, collateralValueInUSD);
    }

    function testDepositCollateral() public {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dscEngine), AMOUNT_COLLATERAL);
        dscEngine.depositCollateral(weth, AMOUNT_COLLATERAL);
        vm.stopPrank();

        uint256 expectDscAmount = 0;
        uint256 expectCollateralValue = 22000e18;

        (uint256 totalDscMInted, uint256 collateralValueInUSD) = dscEngine.getAccountInformation(USER);
        // console.log("totalDscMInted:",totalDscMInted);
        // console.log("collateralValueInUSD:",collateralValueInUSD);
        assertEq(expectDscAmount, totalDscMInted);
        assertEq(expectCollateralValue, collateralValueInUSD);
    }

    function testCanRedeemAllCollateralAndBurnAllDSC() public depositWethAndMint(AMOUNT_COLLATERAL, AMOUNT_MINT) {
        vm.startPrank(USER);
        dsc.approve(address(dscEngine), AMOUNT_MINT);

        dscEngine.redeemAllCollateralAndBurnAllDSC();

        (uint256 totalDscMInted, uint256 collateralValueInUSD) = dscEngine.getAccountInformation(USER);
        assertEq(totalDscMInted, 0);
        assertEq(collateralValueInUSD, 0);
        vm.stopPrank();
    }

    function testCanRedeemCollateral() public depositWethAndMint(AMOUNT_COLLATERAL, AMOUNT_MINT) {
        uint256 redeemAmount = 1e17;

        vm.startPrank(USER);
        dsc.approve(address(dsc), AMOUNT_MINT);
        dscEngine.redeemCollateral(weth, redeemAmount);

        (uint256 totalDscMInted, uint256 collateralValueInUSD) = dscEngine.getAccountInformation(USER);
        assertEq(totalDscMInted, AMOUNT_MINT);
        assertEq(collateralValueInUSD, (AMOUNT_COLLATERAL - redeemAmount) * ETH_PRICE);
        vm.stopPrank();
    }

    function testCanRedeemCollateralAndBurnDSC() public depositWethAndMint(AMOUNT_COLLATERAL, AMOUNT_MINT) {
        uint256 redeemAmount = 1e17;   //0.1 eth
        uint256 dscToBurn = redeemAmount * ETH_PRICE * LIQUIDATION_THRESHOLD / LIQUIDATION_PRECISION;   //0.1*2000*50/100 = 100e18
        console.log("dscToBurn:" ,dscToBurn);
        

        vm.startPrank(USER);
        dsc.approve(address(dscEngine), AMOUNT_MINT);
        dscEngine.redeemCollateralAndBurnDSC(weth, redeemAmount, dscToBurn);

        (uint256 totalDscMInted, uint256 collateralValueInUSD) = dscEngine.getAccountInformation(USER);
        assertEq(totalDscMInted, AMOUNT_MINT - dscToBurn, "totalDscMInted, AMOUNT_MINT"); 
        assertEq(collateralValueInUSD, (AMOUNT_COLLATERAL - redeemAmount) * ETH_PRICE);
        vm.stopPrank();
    }

    function testCanMintDSC() public depositWethAndMint(AMOUNT_COLLATERAL,AMOUNT_MINT){
        uint256 dscToMint = 1e18;
        
        vm.startPrank(USER);
        dscEngine.mintDSC(dscToMint);
       
        (uint256 totalDscMInted, ) = dscEngine.getAccountInformation(USER);
        assertEq(totalDscMInted, AMOUNT_MINT + dscToMint);
 
        vm.stopPrank();
    }

    function testCanBurnDSC()public depositWethAndMint(AMOUNT_COLLATERAL,AMOUNT_MINT){
        uint256 dscToBurn = 1e18;
        
        vm.startPrank(USER);
        dsc.approve(address(dscEngine), dscToBurn);
        dscEngine.burnDSC(dscToBurn);
       
        (uint256 totalDscMInted, ) = dscEngine.getAccountInformation(USER);
        assertEq(totalDscMInted, AMOUNT_MINT - dscToBurn);
 
        vm.stopPrank();
    }

    // function testCanLiquidate()public depositWethAndMint(AMOUNT_COLLATERAL,AMOUNT_MINT){
    //     int256 wethNewPrice = 1000e8;   // 2000e8 -> 1000e8
    //     // 22000usd,11000dsc   
    //     // 11000usd,5500dsc
    //     uint256 debtToCover ; //pay debt
    //     uint256 expectLiquidateCollateralValue;

 

    //     vm.startPrank(LIQUIDATOR);
    //     MockV3Aggregator(wethPriceFeed).updateAnswer(wethNewPrice);
    //     dscEngine.liquidate(weth, USER, )

    // }

    function testCanLiquidate() public depositWethAndMint(AMOUNT_COLLATERAL, AMOUNT_MINT) {
        int256 wethNewPrice = 1000e8; // Step 1: Simulate ETH price drop (8 decimals)
        uint256 debtToCover = AMOUNT_MINT  ; // 10000dsc // Step 2: Cover half of the debt (or choose full amount)  
        
        // Step 3: Start liquidation process
        vm.startPrank(LIQUIDATOR); // impersonate LIQUIDATOR
        ERC20Mock(weth).mint(LIQUIDATOR, 88888 ether);
        ERC20Mock(weth).approve(address(dscEngine), 88888 ether);
        dscEngine.depositCollateralAndMintDSC(weth, 88888 ether, 10000000 ether);
        (uint256  totalDscMInted,uint256 collateralValueInUSD) =  dscEngine.getAccountInformation(LIQUIDATOR );
        console.log("dscEngine.getAccountInformation(LIQUIDATOR )",totalDscMInted);
        MockV3Aggregator(wethPriceFeed).updateAnswer(wethNewPrice); // lower price

        // Step 4: Approve liquidator to burn DSC
        dsc.approve(address(dscEngine), debtToCover); // allow burn

        // Step 5: Call liquidate
        dscEngine.liquidate(weth, USER, debtToCover);

        vm.stopPrank();

        // (Optional) Step 6: Assert changes
        // Check if collateral balance of liquidator increased
        (,uint256 collateralReceived) = dscEngine.getAccountInformation(LIQUIDATOR );
        console.log("collateralReceived", collateralReceived);
        //assertGt(collateralReceived, 0); // liquidator should have received WETH as reward

        // Check if USER's DSC debt is reduced
        (uint256 newDebt, ) = dscEngine.getAccountInformation(USER);
        assertLt(newDebt, AMOUNT_MINT); // should be less than before
    }


    function testRevertWhenBadLiquidation()public{

    }
}
