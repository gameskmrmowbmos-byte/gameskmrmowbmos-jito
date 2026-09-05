import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:matka_management/core/api/api_client.dart';
import 'package:matka_management/core/api/api_endpoints.dart';
import 'package:matka_management/features/new_entry/data/game_config_models.dart';

final gameConfigRepositoryProvider = Provider<GameConfigRepository>(
  (ref) => GameConfigRepository(ref.read(apiClientProvider)),
);

class GameConfigRepository {
  const GameConfigRepository(this._api);

  final ApiClient _api;

  Future<GameConfigModel?> getCurrentConfig(String marketId) async {
    final response = await _api.getJson(
      ApiEndpoints.currentGameConfig,
      query: {'market': marketId},
    );
    final data = response['data'] as Map<String, dynamic>? ?? const {};
    final config = data['gameConfig'];
    if (config is! Map<String, dynamic>) return null;
    return GameConfigModel.fromJson(config);
  }
}
