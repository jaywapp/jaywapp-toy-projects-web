import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/app_strings.dart';
import '../../providers.dart';
import '../../utils/helpers.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_snackbar.dart';
import '../../widgets/section_header.dart';

class NotificationSettingsScreen extends ConsumerWidget {
  const NotificationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupId = ref.watch(selectedGroupIdProvider);
    final user = FirebaseAuth.instance.currentUser;
    if (groupId == null || user == null) {
      return const Scaffold(body: Center(child: Text(AppStrings.selectGroupFirst)));
    }

    final settingsRef = FirebaseFirestore.instance
        .collection('groups')
        .doc(groupId)
        .collection('members')
        .doc(user.uid)
        .collection('notificationSettings')
        .doc('default');

    Future<void> saveSettings({
      required bool noticeEnabled,
      required bool eventReminderEnabled,
      required bool noResponseReminderEnabled,
    }) async {
      try {
        await settingsRef.set({
          'noticeEnabled': noticeEnabled,
          'eventReminderEnabled': eventReminderEnabled,
          'noResponseReminderEnabled': noResponseReminderEnabled,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } on FirebaseException catch (e) {
        if (!context.mounted) return;
        final msg = e.code == 'permission-denied'
            ? kPermissionDeniedMessage
            : "알림 설정 저장에 실패했습니다: ${e.code}";
        AppSnackbar.show(context, message: msg, type: AppSnackType.error);
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            ExcludeSemantics(child: Icon(Icons.notifications_outlined, size: 18)),
            SizedBox(width: 6),
            Text("알림 설정"),
          ],
        ),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: settingsRef.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError)
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(friendlyError(snapshot.error)),
              ),
            );
          if (!snapshot.hasData)
            return const Center(child: CircularProgressIndicator());
          final data = snapshot.data!.data() ?? <String, dynamic>{};
          final noticeEnabled = data['noticeEnabled'] as bool? ?? true;
          final eventReminderEnabled =
              data['eventReminderEnabled'] as bool? ?? true;
          final noResponseReminderEnabled =
              data['noResponseReminderEnabled'] as bool? ?? true;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const SectionHeader(
                title: "알림 설정",
                icon: Icons.notifications_outlined,
              ),
              AppCard(
                child: Column(
                  children: [
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text("공지 알림"),
                      value: noticeEnabled,
                      onChanged: (v) => saveSettings(
                        noticeEnabled: v,
                        eventReminderEnabled: eventReminderEnabled,
                        noResponseReminderEnabled: noResponseReminderEnabled,
                      ),
                    ),
                    const Divider(height: 1),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text("D-1 일정 알림"),
                      value: eventReminderEnabled,
                      onChanged: (v) => saveSettings(
                        noticeEnabled: noticeEnabled,
                        eventReminderEnabled: v,
                        noResponseReminderEnabled: noResponseReminderEnabled,
                      ),
                    ),
                    const Divider(height: 1),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text("매일 13:00 미응답 알림"),
                      value: noResponseReminderEnabled,
                      onChanged: (v) => saveSettings(
                        noticeEnabled: noticeEnabled,
                        eventReminderEnabled: eventReminderEnabled,
                        noResponseReminderEnabled: v,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
