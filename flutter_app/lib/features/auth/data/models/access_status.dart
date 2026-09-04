class AccessStatus {
  const AccessStatus({
    required this.allowed,
    this.code,
    required this.message,
    required this.accountStatus,
    required this.approvalStatus,
    required this.subscriptionType,
    required this.subscriptionStatus,
    this.startDate,
    this.expiryDate,
    this.daysRemaining = 0,
  });

  final bool allowed;
  final String? code;
  final String message;
  final String accountStatus;
  final String approvalStatus;
  final String subscriptionType;
  final String subscriptionStatus;
  final DateTime? startDate;
  final DateTime? expiryDate;
  final int daysRemaining;

  factory AccessStatus.fromJson(Map<String, dynamic> json) {
    return AccessStatus(
      allowed: json['allowed'] == true,
      code: json['code']?.toString(),
      message: json['message']?.toString() ?? '',
      accountStatus: json['accountStatus']?.toString() ?? 'ACTIVE',
      approvalStatus: json['approvalStatus']?.toString() ?? 'APPROVED',
      subscriptionType: json['subscriptionType']?.toString() ??
          (json['subscription'] is Map
              ? (json['subscription'] as Map)['type']?.toString()
              : null) ??
          'NONE',
      subscriptionStatus:
          json['subscriptionStatus']?.toString() ?? 'NOT_ACTIVE',
      startDate: DateTime.tryParse(json['startDate']?.toString() ?? ''),
      expiryDate: DateTime.tryParse(json['expiryDate']?.toString() ?? ''),
      daysRemaining: int.tryParse(json['daysRemaining']?.toString() ?? '') ?? 0,
    );
  }
}
