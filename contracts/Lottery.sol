// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;

contract LotteryGame {
    // 彩票資訊
    struct Egginfo {
        bytes32 uid; // 購買彩票id , 32 * 8  = 256位
        uint8 mul; // 倍數
        uint248 blocknumber; //區塊號碼
    }

    // 開獎號碼
    struct OpenedLotInfo {
        uint32 Lotterynum; // 開獎號碼
        uint8 mul; // 倍數
    }

    // 用戶資訊
    struct userinfo {
        Egginfo[] egginfo; // 彩票購買紀錄
        OpenedLotInfo[] openedLotInfo; // 最近一次開獎號碼
        uint256 ReferralProfit; // 紀錄推薦獎勵
        bool actived; // 是否激活,用於需要自己購買至少一注彩票推薦才有效
    }

    // 中獎資訊
    struct Winninginfo {
        uint32 LotteryNum; // 彩票號碼
        uint8 mul; // 倍數
        uint256 timestamp; // 購買彩票時間區塊時間戳
        address winner; // 中獎人地址
    }

    // 投資者資訊
    struct investorbalance {
        uint256 balance; // 餘額
        uint256 LastInvestTime; // 最近一次投資時間,投資時間必須至少7天才能取回
        bool HasInvested; // 是否已經投資過，沒有投資過不能分紅
    }

    // 每注彩票金額
    uint256 private constant PerEggPrice = 0.02 ether; // 0.02BNB

    // 接受投資的獎池最大值(獎池小於10000時才能投資)
    uint256 private constant Maxinum_Investment_pool = 10000 ether; // 10000BNB

    // 最小投資金額
    uint256 private constant Mininum_Investment_amount = 1 ether; // 1BNB

    // 最大投資金額
    uint256 private constant Maxinum_Investment_amount = 1000 ether; // 1000BNB

    // 開發者地址
    address public DevAddress;

    // 開發者收益 所有彩票購買金額3% + 所有中獎金額的5%
    uint256 private DevProfit;

    // 所有投資者的地址 分配投資收益
    address[] private investors;

    // 投資者資訊: 紀錄投資金額.投資時間
    mapping(address => investorbalance) private InvestorsBalance;

    // 投資者總投資金額
    uint256 public TotalInvestmentAmount;

    // 投資者收益: 所有中獎金額的5%
    uint256 public InvestorsProfit;

    // 最近一次分紅時間
    uint256 public RecentDividendTime;

    // 所有推薦者獎勵, 方便計算獎池 (獎池 = 合約餘額 - 推薦者推薦 - 投資者收益 - 開發者收益)
    uint256 private TotalReferralProfit;

    // 最近一次購買彩票時間: 當合約長期(15天)無人購買彩票時，允許開發者銷毀
    uint256 private LastBuyEggTime;

    // 所有用戶資訊
    mapping(address => userinfo) private UsersInfo;

    // 所有推薦者資訊: 紀錄推薦關係 , A地址推薦了B地址
    mapping(address => address) private referrals;

    // 所有中獎紀錄資訊: 紀錄所有人的中獎紀錄 方便公開中獎資訊
    Winninginfo[] private WinningRecord;

    constructor() {
        DevAddress = msg.sender;
        RecentDividendTime = block.timestamp;
        LastBuyEggTime = block.timestamp;
    }

    // 安全加法
    // internal:只能在合約內部使用（或被繼承的合約使用）; pure: 這個函數只依賴輸入參數，不讀取也不改寫區塊鏈上的資料（狀態變數）不會消耗gas fee
    // 使用assert判斷若發生錯誤行為(惡意行為)會扣除gas fee ,使用require則不會扣除
    function SafeMathadd(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        assert(c >= a);

        return c;
    }

    // 安全減法
    function SafeMathsub(uint256 a, uint256 b) internal pure returns (uint256) {
        assert(b <= a);

        return a - b;
    }

    // 安全乘法
    function SafeMathmul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        }

        uint256 c = a * b;

        assert((c / a) == b);

        return c;
    }

    // 安全除法
    function SafeMathdiv(uint256 a, uint256 b) internal pure returns (uint256) {
        assert(b > 0);

        uint256 c = a / b;

        return c;
    }
}
