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
        bool HasInvested; // 是否已經投資過
    }
}
