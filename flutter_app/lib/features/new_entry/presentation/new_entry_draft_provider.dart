import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:matka_management/features/entries/data/receipt_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

class JackpotEntryData {
  String number;
  String amount;

  JackpotEntryData({
    required this.number,
    required this.amount,
  });

  Map<String, dynamic> toJson() => {
        'number': number,
        'amount': amount,
      };

  factory JackpotEntryData.fromJson(Map<String, dynamic> json) {
    return JackpotEntryData(
      number: json['number']?.toString() ?? '',
      amount: json['amount']?.toString() ?? '',
    );
  }
}

class BetEntryData {
  String number;
  String amount;
  bool isJackpot;
  List<JackpotEntryData> jackpotEntries;
  String? sessionOverride;

  BetEntryData({
    required this.number,
    required this.amount,
    this.isJackpot = false,
    List<JackpotEntryData>? jackpotEntries,
    this.sessionOverride,
  }) : jackpotEntries = jackpotEntries ?? const [];

  Map<String, dynamic> toJson() => {
        'number': number,
        'amount': amount,
        'isJackpot': isJackpot,
        'sessionOverride': sessionOverride,
        'jackpotEntries':
            jackpotEntries.map((entry) => entry.toJson()).toList(),
      };

  factory BetEntryData.fromJson(Map<String, dynamic> json) {
    return BetEntryData(
      number: json['number']?.toString() ?? '',
      amount: json['amount']?.toString() ?? '',
      isJackpot: json['isJackpot'] == true,
      sessionOverride: json['sessionOverride']?.toString(),
      jackpotEntries: (json['jackpotEntries'] as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(JackpotEntryData.fromJson)
          .toList(),
    );
  }
}

class NewEntryDraftState {
  final String? userId;
  final ReceiptMarket? market;
  final String? marketId;
  final String session;
  final bool isOtc;
  final Set<int> otcPages;
  final List<BetEntryData> manualEntries;
  final Map<String, int> localParchiCounters;

  NewEntryDraftState({
    this.userId,
    this.market,
    String? marketId,
    this.session = 'Open',
    this.isOtc = false,
    Set<int>? otcPages,
    List<BetEntryData>? manualEntries,
    Map<String, int>? localParchiCounters,
  })  : marketId = marketId ?? market?.id,
        otcPages = otcPages ?? (isOtc ? {0} : <int>{}),
        manualEntries = manualEntries ?? [BetEntryData(number: '', amount: '')],
        localParchiCounters = localParchiCounters ?? {};

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'market': market == null
            ? null
            : {
                'id': market!.id,
                'name': market!.name,
                'code': market!.code,
                'gameConfigCode': market!.gameConfigCode,
                'isActive': market!.isActive,
                'displayOrder': market!.displayOrder,
              },
        'marketId': marketId,
        'session': session,
        'isOtc': isOtc || otcPages.isNotEmpty,
        'otcPages': otcPages.toList()..sort(),
        'manualEntries': manualEntries.map((entry) => entry.toJson()).toList(),
        'localParchiCounters': localParchiCounters,
      };

  factory NewEntryDraftState.fromJson(Map<String, dynamic> json) {
    final marketMap = json['market'] is Map<String, dynamic>
        ? json['market'] as Map<String, dynamic>
        : null;
    final isOtc = json['isOtc'] == true;
    final otcPages = _otcPagesFromJson(json['otcPages']);
    final counters = <String, int>{};
    final rawCounters = json['localParchiCounters'];
    if (rawCounters is Map) {
      for (final entry in rawCounters.entries) {
        final value = entry.value;
        counters[entry.key.toString()] =
            value is int ? value : int.tryParse(value?.toString() ?? '') ?? 1;
      }
    }
    return NewEntryDraftState(
      userId: json['userId']?.toString(),
      market: marketMap == null
          ? null
          : ReceiptMarket(
              id: marketMap['id']?.toString() ?? '',
              name: marketMap['name']?.toString() ?? '',
              code: marketMap['code']?.toString() ?? '',
              gameConfigCode: marketMap['gameConfigCode']?.toString() ?? '',
              isActive: marketMap['isActive'] != false,
              displayOrder: marketMap['displayOrder'] is int
                  ? marketMap['displayOrder'] as int
                  : int.tryParse(marketMap['displayOrder']?.toString() ?? '') ??
                      0,
            ),
      marketId: json['marketId']?.toString(),
      session: json['session']?.toString() == 'Close' ? 'Close' : 'Open',
      manualEntries: (json['manualEntries'] as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(BetEntryData.fromJson)
          .toList(),
      localParchiCounters: counters,
      isOtc: isOtc,
      otcPages: otcPages.isEmpty && isOtc ? {0} : otcPages,
    );
  }
}

class NewEntryDraftNotifier extends Notifier<NewEntryDraftState> {
  static const _keyPrefix = 'new_entry_draft_';

  @override
  NewEntryDraftState build() {
    return NewEntryDraftState();
  }

  Future<void> loadForUser(String userId) async {
    if (state.userId == userId) return;
    final preferences = await SharedPreferences.getInstance();
    final rawDraft = preferences.getString('$_keyPrefix$userId');
    if (rawDraft == null || rawDraft.isEmpty) {
      state = NewEntryDraftState(userId: userId);
      return;
    }
    try {
      final decoded = jsonDecode(rawDraft);
      state = decoded is Map<String, dynamic>
          ? NewEntryDraftState.fromJson(decoded)
          : NewEntryDraftState(userId: userId);
      if (state.userId != userId) {
        state = NewEntryDraftState(userId: userId);
      }
    } on Object {
      state = NewEntryDraftState(userId: userId);
    }
  }

  Future<void> updateDraft(NewEntryDraftState newState) async {
    state = newState;
    final userId = newState.userId;
    if (userId == null || userId.isEmpty) return;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
        '$_keyPrefix$userId', jsonEncode(newState.toJson()));
  }

  Future<void> clearDraft({String? userId}) async {
    final counters = state.localParchiCounters;
    state = NewEntryDraftState(
      userId: userId ?? state.userId,
      market: state.market,
      marketId: state.marketId,
      session: state.session,
      isOtc: false,
      otcPages: const <int>{},
      localParchiCounters: counters,
    );
    final activeUserId = state.userId;
    if (activeUserId == null || activeUserId.isEmpty) return;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
        '$_keyPrefix$activeUserId', jsonEncode(state.toJson()));
  }

  void clearActive() {
    state = NewEntryDraftState();
  }
}

final newEntryDraftProvider =
    NotifierProvider<NewEntryDraftNotifier, NewEntryDraftState>(() {
  return NewEntryDraftNotifier();
});

Set<int> _otcPagesFromJson(Object? value) {
  if (value is! List) return <int>{};
  return value
      .map((entry) =>
          entry is int ? entry : int.tryParse(entry?.toString() ?? ''))
      .whereType<int>()
      .where((entry) => entry >= 0)
      .toSet();
}
