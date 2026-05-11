import 'package:shared_preferences/shared_preferences.dart';
import 'package:pos_flutter/core/network/network_models.dart';

class RuntimeSetupConfig {
  final bool isSetupComplete;
  final String language;
  final SyncProfile? syncProfile;

  const RuntimeSetupConfig({
    required this.isSetupComplete,
    required this.language,
    this.syncProfile,
  });
}

class RuntimeConfigRepository {
  static const _kSetupComplete = 'setup_complete';
  static const _kHost = 'connection_host';
  static const _kPort = 'connection_port';
  static const _kBasePath = 'connection_base_path';
  static const _kCustCode = 'sync_cust_code';
  static const _kBootstrapUserId = 'sync_bootstrap_user_id';
  static const _kPageLimit = 'sync_page_limit';
  static const _kUseSsl = 'connection_use_ssl';
  static const _kLanguage = 'app_language';

  Future<RuntimeSetupConfig> loadSetupConfig() async {
    final prefs = await SharedPreferences.getInstance();
    var isComplete = prefs.getBool(_kSetupComplete) ?? false;
    final language = prefs.getString(_kLanguage) ?? 'en';

    SyncProfile? syncProfile;
    final host = prefs.getString(_kHost);
    final custCode = prefs.getString(_kCustCode);

    if (host != null &&
        host.isNotEmpty &&
        custCode != null &&
        custCode.isNotEmpty) {
      syncProfile = SyncProfile(
        host: host,
        port: prefs.getInt(_kPort),
        basePath: prefs.getString(_kBasePath) ?? '/ords/erp/pos-api/v1',
        custCode: custCode,
        bootstrapUserId: prefs.getString(_kBootstrapUserId) ?? '1',
        pageLimit: _normalizePageLimit(prefs.getInt(_kPageLimit)),
        useSsl: prefs.getBool(_kUseSsl) ?? true,
      );
    } else if (isComplete) {
      isComplete = false;
      await prefs.setBool(_kSetupComplete, false);
    }

    return RuntimeSetupConfig(
      isSetupComplete: isComplete,
      language: language,
      syncProfile: syncProfile,
    );
  }

  Future<void> saveSyncProfile(SyncProfile profile) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kHost, profile.host);
    if (profile.port != null) {
      await prefs.setInt(_kPort, profile.port!);
    } else {
      await prefs.remove(_kPort);
    }
    await prefs.setString(_kBasePath, profile.basePath);
    await prefs.setString(_kCustCode, profile.custCode);
    await prefs.setString(_kBootstrapUserId, profile.bootstrapUserId);
    await prefs.setInt(_kPageLimit, _normalizePageLimit(profile.pageLimit));
    await prefs.setBool(_kUseSsl, profile.useSsl);
  }


  int _normalizePageLimit(int? value) {
    final limit = value ?? 500;
    if (limit < 500) return 500;
    if (limit > 1000) return 1000;
    return limit;
  }

  Future<void> setSetupComplete(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kSetupComplete, value);
  }

  Future<void> setLanguage(String language) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kLanguage, language);
  }

  Future<void> resetSetupStatus() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kSetupComplete, false);
  }

  Future<void> clearSyncProfile() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kHost);
    await prefs.remove(_kPort);
    await prefs.remove(_kBasePath);
    await prefs.remove(_kCustCode);
    await prefs.remove(_kBootstrapUserId);
    await prefs.remove(_kPageLimit);
    await prefs.remove(_kUseSsl);
  }
}
