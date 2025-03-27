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
        Egginfo[] eggsinfo; // 彩票購買紀錄
        OpenedLotInfo[] openedeggs; // 最近一次開獎號碼
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

    // 購買彩票
    function BuyEggs(
        uint16 LotCount,
        uint8 mul,
        uint232 Lucknum,
        address ref
    ) external payable {
        require(msg.value >= PerEggPrice, "Buy at least one egg");
        require(mul >= 1 && mul <= 100, "Multiples between 1 and 100");
        require(
            LotCount >= 1 && LotCount <= 1000,
            "Number of eggs between 1 and 100"
        );
        uint256 AllLotteryCount = SafeMathdiv(msg.value, PerEggPrice);

        require(AllLotteryCount == LotCount * mul, "Invalid data");

        for (uint256 i = 0; i < LotCount; i++) {
            Egginfo memory egginfo = Egginfo(
                keccak256(
                    abi.encodePacked(
                        block.timestamp,
                        block.coinbase,
                        msg.sender,
                        Lucknum++
                    )
                ),
                mul,
                uint248(block.number)
            );

            UsersInfo[msg.sender].eggsinfo.push(egginfo);
        }

        if (!UsersInfo[msg.sender].actived)
            UsersInfo[msg.sender].actived = true;

        // 投資返勵
        uint256 profit = SafeMathdiv(SafeMathmul(msg.value, 3), 100);

        // 推薦返勵
        uint256 Refprofit = SafeMathdiv(SafeMathmul(msg.value, 4), 100);

        // 開發者加上3%
        DevProfit += profit;

        // 投資者加上3%
        InvestorsProfit += profit;

        // 判斷目前推薦者是否為空
        if (referrals[msg.sender] == address(0)) {
            // 判斷傳入的推薦者地址是否有效

            // 不能將自己作為推薦者||傳入為空||未激活
            if (
                ref == msg.sender ||
                ref == address(0) ||
                !UsersInfo[msg.sender].actived
            ) {
                // 如果傳入無效值就以開發者地址當作推薦人
                ref = DevAddress;
            }
            referrals[msg.sender] = ref;

            // 判斷推薦者是否為開發者,若為真再加上推薦獎勵
            if (referrals[msg.sender] == DevAddress) {
                DevProfit += Refprofit;
            } else {
                UsersInfo[referrals[msg.sender]].ReferralProfit += Refprofit;
                TotalReferralProfit += Refprofit;
            }

            LastBuyEggTime = block.timestamp;
        }
    }

    // 根據開獎號碼計算中獎等級
    function GetWinninggrade(uint32 LotteryNum) private pure returns (uint256) {
        if (LotteryNum > 67108864) return 0;
        if (LotteryNum >= 16777216) return 10;
        if (LotteryNum >= 4194304) return 9;
        if (LotteryNum >= 1048576) return 8;
        if (LotteryNum >= 262144) return 7;
        if (LotteryNum >= 65536) return 6;
        if (LotteryNum >= 16384) return 5;
        if (LotteryNum >= 4096) return 4;
        if (LotteryNum >= 1024) return 3;
        if (LotteryNum >= 256) {
            return 2;
        } else {
            return 1;
        }
    }

    // 根據中獎等級計算獲獎倍數
    function GetWinningmultiple(uint256 winninginfo)
        private
        pure
        returns (uint256)
    {
        if (winninginfo == 0) return 0;
        if (winninginfo == 10) return 5;
        if (winninginfo == 9) return 20;
        if (winninginfo == 8) return 80;
        if (winninginfo == 7) return 320;
        if (winninginfo == 6) return 1200;
        if (winninginfo == 5) return 4800;
        if (winninginfo == 4) return 20000;
        if (winninginfo == 3) return 100000;
        if (winninginfo == 2) return 500000;
        if (winninginfo == 1) return 2000000;

        return 0;
    }

    // 彩票開獎
    function OpenEggs() external {
        // 判斷開獎的人有沒有未開獎的彩票
        require(
            UsersInfo[msg.sender].eggsinfo.length > 0,
            "You don't have undraw lottery tickets"
        );

        // 判斷區塊號 當前區塊號是否>購買彩票區塊號大 , 不能在購買的彩票區塊上開獎
        require(
            block.number >
                UsersInfo[msg.sender]
                    .eggsinfo[UsersInfo[msg.sender].eggsinfo.length - 1]
                    .blocknumber,
            "It's not time"
        );

        // 判斷是否有過往開獎號碼，有的話移除保存新的
        if (UsersInfo[msg.sender].openedeggs.length > 0)
            delete UsersInfo[msg.sender].openedeggs;

        // 彩票總中獎金額
        uint256 WinningAmount;

        for (uint256 i = 0; i < UsersInfo[msg.sender].eggsinfo.length; i++) {
            // 判斷是否失效 超過256區塊後就會失效

            if (
                uint256(
                    blockhash(UsersInfo[msg.sender].eggsinfo[i].blocknumber)
                ) == 0
            ) continue;

            // 計算開獎號碼
            uint32 LotteryNum = uint32(
                bytes4(
                    keccak256(
                        abi.encodePacked(
                            UsersInfo[msg.sender].eggsinfo[i].uid,
                            blockhash(
                                UsersInfo[msg.sender].eggsinfo[i].blocknumber
                            )
                        )
                    )
                )
            );

            // 中獎等級
            uint256 Winningrade = GetWinninggrade(LotteryNum);

            // 判斷是否中獎
            if (Winningrade > 0) {
                uint256 WinningMoney = GetWinningmultiple(Winningrade) *
                    UsersInfo[msg.sender].eggsinfo[i].mul *
                    PerEggPrice;

                WinningAmount += WinningMoney;

                Winninginfo memory winning = Winninginfo(
                    LotteryNum,
                    UsersInfo[msg.sender].eggsinfo[i].mul,
                    uint40(block.timestamp),
                    msg.sender
                );

                WinningRecord.push(winning);
            }

            OpenedLotInfo memory OpenedLotterys = OpenedLotInfo(
                LotteryNum,
                UsersInfo[msg.sender].eggsinfo[i].mul
            );

            UsersInfo[msg.sender].openedeggs.push(OpenedLotterys);
        }

        // 刪除用戶購買紀錄刪除避免重複開獎
        delete UsersInfo[msg.sender].eggsinfo;

        // 每次中獎金額不能超過總獎池的70%
        if (WinningAmount > 0) {
            uint256 MaxWinningAmount = SafeMathdiv(
                SafeMathmul(
                    SafeMathsub(
                        address(this).balance,
                        (InvestorsProfit + TotalReferralProfit + DevProfit)
                    ),
                    70
                ),
                100
            );

            if (WinningAmount > MaxWinningAmount)
                WinningAmount = MaxWinningAmount;

            uint256 profit = SafeMathdiv(SafeMathmul(WinningAmount, 5), 100);
            InvestorsProfit += profit;
            DevProfit += profit;

            payable(msg.sender).transfer(WinningAmount - profit * 2);
        }
    }

    // 投資者投資
    function InvestmentDeposit() external payable {
        // 判斷投資金額是否符合要求
        require(
            msg.value >= Mininum_Investment_amount &&
                msg.value <= Maxinum_Investment_amount,
            "Investment amount beteween 1 and 1000"
        );

        // 判斷獎池金額
        require(
            SafeMathsub(
                address(this).balance,
                (InvestorsProfit + TotalReferralProfit + DevProfit)
            ) <= Maxinum_Investment_pool
        );

        // 累加總投資金額
        TotalInvestmentAmount += msg.value;
        // 累加該投資者投資金額
        InvestorsBalance[msg.sender].balance += msg.value;
        InvestorsBalance[msg.sender].LastInvestTime = block.timestamp;

        // 判斷投資者是否是第一次投資
        if (!InvestorsBalance[msg.sender].HasInvested) {
            InvestorsBalance[msg.sender].HasInvested = true;
            investors.push(msg.sender);
        }
    }

    // 投資者退出
    function InvestmentWithdrawal(uint256 WithdrawalAmount) external {
        // 判斷取款金額是否大於最小投資金額
        require(
            WithdrawalAmount >= Mininum_Investment_amount,
            "Minimum investment amount is required,it's smaller than the minimum deposit"
        );

        // 判斷金額是否足夠
        require(
            WithdrawalAmount <= InvestorsBalance[msg.sender].balance,
            "Not enough fund to withdraw!"
        );

        // 判斷當前時間和上一次投資時間是否已經超過1周，1周以上才能退出投資
        require(
            block.timestamp >=
                InvestorsBalance[msg.sender].LastInvestTime + 1 weeks,
            "Cannot withdraw after one week!"
        );

        // 判斷獎池金額是否足夠，不足時無法取出
        require(
            SafeMathsub(
                address(this).balance,
                (InvestorsProfit + TotalReferralProfit + DevProfit)
            ) >= WithdrawalAmount,
            "Insufficient fund to withdraw!"
        );

        // 該投資者投資金額減去本次取款金額
        InvestorsBalance[msg.sender].balance -= WithdrawalAmount;
        // 總投資額也減去
        TotalInvestmentAmount -= WithdrawalAmount;
        // 把本次取款金額歸還
        payable(msg.sender).transfer(WithdrawalAmount);
    }

    // 投資者分紅
    function DistributeInvestmentIncome() external {
        // 判斷發起者是否有資格 只有投資者或開發者才能夠發起分紅
        require(
            InvestorsBalance[msg.sender].balance >= Mininum_Investment_amount ||
                msg.sender == DevAddress,
            "You must be a investor"
        );

        uint256 Tmpinvestorsprofit = InvestorsProfit;
        uint256 developeraward = 0;

        // 總獎池超過10000時0.5%給投資者 0.5%給開發者
        uint256 prizepool = SafeMathsub(
            address(this).balance,
            (InvestorsProfit + TotalReferralProfit + DevProfit)
        );

        if (prizepool >= Maxinum_Investment_pool) {
            Tmpinvestorsprofit += prizepool / 200;
            developeraward += prizepool / 200;
        }
        InvestorsProfit = 0;

        for (uint256 i = 0; i < investors.length; i++) {
            if (
                InvestorsBalance[investors[i]].balance >=
                Mininum_Investment_amount
            ) {
                // 他的分紅= 他的投資 / 總投資 * 投資者總收益

                uint256 thisinvestorprofit = SafeMathdiv(
                    SafeMathmul(
                        InvestorsBalance[investors[i]].balance,
                        Tmpinvestorsprofit
                    ),
                    TotalInvestmentAmount
                );

                payable(investors[i]).transfer(thisinvestorprofit);
            }
        }

        if (developeraward > 0) {
            payable(DevAddress).transfer(developeraward);
        }
    }
}
