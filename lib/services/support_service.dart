import 'supabase_service.dart';

class SupportService {
  Future<void> registerSupportDeclaration({
    required int amountFcfa,
    String channel = 'ussd',
    String? appVersion,
  }) async {
    if (!SupabaseService.isEnabled) {
      throw Exception('Supabase non configure');
    }

    final user = SupabaseService.currentUser;
    if (user == null) {
      throw Exception('Connexion requise');
    }

    await SupabaseService.client.rpc(
      'register_support_declaration',
      params: {
        'p_amount_fcfa': amountFcfa,
        'p_channel': channel,
        'p_app_version': appVersion,
      },
    );
  }
}
