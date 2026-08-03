class CouponData {
  int? couponId;
  String? couponName;
  String? rewardAmount;
  String? walletBalance;

  CouponData({
    this.couponId,
    this.couponName,
    this.rewardAmount,
    this.walletBalance,
  });

  CouponData.fromJson(Map<String, dynamic> json) {
    couponId = json['coupon_id'] is int
        ? json['coupon_id']
        : int.tryParse(json['coupon_id']?.toString() ?? '');
    couponName = json['coupon_name']?.toString();
    rewardAmount = json['reward_amount']?.toString();
    walletBalance = json['wallet_balance']?.toString();
  }
}

class CouponHistoryItem {
  String? coupon;
  String? couponName;
  String? reward;
  String? redeemedAt;

  CouponHistoryItem({
    this.coupon,
    this.couponName,
    this.reward,
    this.redeemedAt,
  });

  CouponHistoryItem.fromJson(Map<String, dynamic> json) {
    coupon = json['coupon']?.toString();
    couponName = json['coupon_name']?.toString();
    reward = json['reward']?.toString();
    redeemedAt = json['redeemed_at']?.toString();
  }
}
