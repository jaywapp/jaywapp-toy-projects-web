import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_snackbar.dart';

class DebugPanelCard extends StatelessWidget {
  const DebugPanelCard({
    super.key,
    required this.uid,
    required this.selectedGroupId,
    required this.memberDocExists,
    required this.memberStatus,
    required this.lastFirestoreError,
    required this.currentFcmToken,
    required this.tokenStored,
    required this.notificationSettingsSummary,
  });

  final String? uid;
  final String? selectedGroupId;
  final bool? memberDocExists;
  final String? memberStatus;
  final String? lastFirestoreError;
  final String? currentFcmToken;
  final bool? tokenStored;
  final String? notificationSettingsSummary;

  @override
  Widget build(BuildContext context) {
    final copyText = _buildDebugCopyText();
    return Card(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'DEBUG',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                TextButton.icon(
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: copyText));
                    if (context.mounted) {
                      AppSnackbar.show(
                        context,
                        message: '디버그 정보를 복사했습니다.',
                        type: AppSnackType.info,
                      );
                    }
                  },
                  icon: const Icon(Icons.copy, size: 16),
                  label: const Text('복사'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('uid: ${uid ?? 'NULL'}'),
            Text('selectedGroupId: ${selectedGroupId ?? 'NULL'}'),
            Text(
              'memberDocExists: ${memberDocExists?.toString() ?? 'unknown'}',
            ),
            Text('memberStatus: ${memberStatus ?? 'unknown'}'),
            Text('lastError: ${lastFirestoreError ?? 'none'}'),
            Text('fcmToken: ${currentFcmToken ?? 'none'}'),
            Text('tokenStored: ${tokenStored?.toString() ?? 'unknown'}'),
            Text('settings: ${notificationSettingsSummary ?? 'unknown'}'),
          ],
        ),
      ),
    );
  }

  String _buildDebugCopyText() {
    return [
      'uid: ${uid ?? 'NULL'}',
      'selectedGroupId: ${selectedGroupId ?? 'NULL'}',
      'memberDocExists: ${memberDocExists?.toString() ?? 'unknown'}',
      'memberStatus: ${memberStatus ?? 'unknown'}',
      'lastError: ${lastFirestoreError ?? 'none'}',
      'fcmToken: ${currentFcmToken ?? 'none'}',
      'tokenStored: ${tokenStored?.toString() ?? 'unknown'}',
      'settings: ${notificationSettingsSummary ?? 'unknown'}',
    ].join('\n');
  }
}
