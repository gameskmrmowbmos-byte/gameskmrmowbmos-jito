class AuthUser {
  const AuthUser({
    required this.id,
    required this.fullName,
    this.ownerName,
    required this.username,
    required this.email,
    required this.role,
    required this.isActive,
    this.approvalStatus = 'APPROVED',
    this.accountStatus = 'ACTIVE',
    this.emailVerified = false,
    this.subscriptionType = 'NONE',
    this.subscriptionStatus = 'NOT_ACTIVE',
    this.subscriptionStartDate,
    this.subscriptionExpiryDate,
    this.assignedMarketIds = const [],
    this.phoneNumber,
    this.lastLogin,
  });

  final String id;
  final String fullName;
  final String? ownerName;
  final String username;
  final String email;
  final String role;
  final bool isActive;
  final String approvalStatus;
  final String accountStatus;
  final bool emailVerified;
  final String subscriptionType;
  final String subscriptionStatus;
  final DateTime? subscriptionStartDate;
  final DateTime? subscriptionExpiryDate;
  final List<String> assignedMarketIds;
  final String? phoneNumber;
  final DateTime? lastLogin;

  bool get isAdmin => role == 'admin';

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    final rawMarkets = json['assignedMarkets'];
    return AuthUser(
      id: (json['id'] ?? json['_id']).toString(),
      fullName: json['fullName']?.toString() ?? '',
      ownerName: json['ownerName']?.toString(),
      username: json['username']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      role: json['role']?.toString() ?? 'operator',
      isActive: json['isActive'] as bool? ?? false,
      approvalStatus: json['approvalStatus']?.toString() ?? 'APPROVED',
      accountStatus: json['accountStatus']?.toString() ?? 'ACTIVE',
      emailVerified: json['emailVerified'] == true,
      subscriptionType: json['subscriptionType']?.toString() ?? 'NONE',
      subscriptionStatus:
          json['subscriptionStatus']?.toString() ?? 'NOT_ACTIVE',
      subscriptionStartDate:
          DateTime.tryParse(json['subscriptionStartDate']?.toString() ?? ''),
      subscriptionExpiryDate:
          DateTime.tryParse(json['subscriptionExpiryDate']?.toString() ?? ''),
      assignedMarketIds: rawMarkets is List
          ? rawMarkets.map((item) {
              if (item is Map) return (item['_id'] ?? item['id']).toString();
              return item.toString();
            }).toList()
          : const [],
      phoneNumber: json['phoneNumber']?.toString(),
      lastLogin: DateTime.tryParse(json['lastLogin']?.toString() ?? ''),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'fullName': fullName,
        'ownerName': ownerName,
        'username': username,
        'email': email,
        'role': role,
        'isActive': isActive,
        'approvalStatus': approvalStatus,
        'accountStatus': accountStatus,
        'emailVerified': emailVerified,
        'subscriptionType': subscriptionType,
        'subscriptionStatus': subscriptionStatus,
        'subscriptionStartDate': subscriptionStartDate?.toIso8601String(),
        'subscriptionExpiryDate': subscriptionExpiryDate?.toIso8601String(),
        'assignedMarkets': assignedMarketIds,
        'phoneNumber': phoneNumber,
        'lastLogin': lastLogin?.toIso8601String(),
      };
}
