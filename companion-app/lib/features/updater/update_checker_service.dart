import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

class UpdateInfo {
  final String currentVersion;
  final String latestVersion;
  final String releaseNotes;
  final String downloadUrl;
  final bool hasUpdate;

  const UpdateInfo({
    required this.currentVersion,
    required this.latestVersion,
    required this.releaseNotes,
    required this.downloadUrl,
    required this.hasUpdate,
  });

  factory UpdateInfo.empty(String currentVersion) {
    return UpdateInfo(
      currentVersion: currentVersion,
      latestVersion: currentVersion,
      releaseNotes: '',
      downloadUrl: '',
      hasUpdate: false,
    );
  }
}

class UpdateCheckerNotifier extends StateNotifier<AsyncValue<UpdateInfo>> {
  static const String currentAppVersion = '0.2.1';
  static const String repoOwner = 'roshancodespace';
  static const String repoName = 'koder';

  final http.Client _client;

  UpdateCheckerNotifier({http.Client? client})
      : _client = client ?? http.Client(),
        super(AsyncValue.data(UpdateInfo.empty(currentAppVersion)));

  Future<UpdateInfo> checkForUpdates() async {
    state = const AsyncValue.loading();
    try {
      final url = Uri.parse(
        'https://api.github.com/repos/$repoOwner/$repoName/releases/latest',
      );
      final response = await _client.get(
        url,
        headers: {
          'Accept': 'application/vnd.github.v3+json',
          'User-Agent': 'VSCode-Companion-App',
        },
      );

      if (response.statusCode != 200) {
        final info = UpdateInfo.empty(currentAppVersion);
        state = AsyncValue.data(info);
        return info;
      }

      final Map<String, dynamic> data =
          jsonDecode(response.body) as Map<String, dynamic>;
      final tagName = (data['tag_name'] as String? ?? '').replaceFirst('v', '');
      final body = data['body'] as String? ?? 'No release notes provided.';
      final assets = data['assets'] as List<dynamic>? ?? [];

      String downloadUrl = '';
      for (final asset in assets) {
        if (asset is Map<String, dynamic>) {
          final name = asset['name'] as String? ?? '';
          if (name.endsWith('.apk')) {
            downloadUrl = asset['browser_download_url'] as String? ?? '';
            break;
          }
        }
      }

      final hasUpdate = _isNewerVersion(tagName, currentAppVersion);
      final info = UpdateInfo(
        currentVersion: currentAppVersion,
        latestVersion: tagName.isNotEmpty ? tagName : currentAppVersion,
        releaseNotes: body,
        downloadUrl: downloadUrl,
        hasUpdate: hasUpdate,
      );

      state = AsyncValue.data(info);
      return info;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return UpdateInfo.empty(currentAppVersion);
    }
  }

  bool _isNewerVersion(String latest, String current) {
    if (latest.isEmpty) return false;
    try {
      final latestParts = latest.split('.').map(int.parse).toList();
      final currentParts = current.split('.').map(int.parse).toList();

      for (int i = 0; i < latestParts.length && i < currentParts.length; i++) {
        if (latestParts[i] > currentParts[i]) return true;
        if (latestParts[i] < currentParts[i]) return false;
      }
      return latestParts.length > currentParts.length;
    } catch (_) {
      return latest != current;
    }
  }
}

final updateCheckerProvider =
    StateNotifierProvider<UpdateCheckerNotifier, AsyncValue<UpdateInfo>>((ref) {
  return UpdateCheckerNotifier();
});
