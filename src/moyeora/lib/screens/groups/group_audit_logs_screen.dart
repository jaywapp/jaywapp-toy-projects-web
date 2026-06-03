import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../services/permission_service.dart';
import '../../utils/helpers.dart';
import '../../widgets/app_card.dart';
import '../../widgets/section_header.dart';

enum _OperationLogFilter { all, role, member, invite }

enum _OperationLogPeriod { all, today, days7, days30 }

class GroupAuditLogsScreen extends StatefulWidget {
  const GroupAuditLogsScreen({super.key, required this.groupId});

  final String groupId;

  @override
  State<GroupAuditLogsScreen> createState() => _GroupAuditLogsScreenState();
}

class _GroupAuditLogsScreenState extends State<GroupAuditLogsScreen> {
  _OperationLogFilter _filter = _OperationLogFilter.all;
  _OperationLogPeriod _period = _OperationLogPeriod.all;

  bool _matchesFilter(String action) {
    return switch (_filter) {
      _OperationLogFilter.all => true,
      _OperationLogFilter.role =>
        action.startsWith('role.') || action == 'owner.delegate',
      _OperationLogFilter.member => action == 'member.approve',
      _OperationLogFilter.invite => action.startsWith('invite.'),
    };
  }

  String _actionLabel(String action) {
    return switch (action) {
      'role.update' => '권한 변경',
      'owner.delegate' => '모임장 위임',
      'member.requestJoin' => '가입 요청',
      'member.approve' => '가입 승인',
      'invite.create' => '초대코드 발급',
      'invite.revoke' => '초대코드 회수',
      _ => action,
    };
  }

  String _filterLabel(_OperationLogFilter filter) {
    return switch (filter) {
      _OperationLogFilter.all => '전체',
      _OperationLogFilter.role => '권한변경',
      _OperationLogFilter.member => '가입승인',
      _OperationLogFilter.invite => '초대관리',
    };
  }

  Widget _filterChip(_OperationLogFilter filter) {
    return ChoiceChip(
      label: Text(_filterLabel(filter)),
      selected: _filter == filter,
      onSelected: (_) => setState(() => _filter = filter),
    );
  }

  String _periodLabel(_OperationLogPeriod period) {
    return switch (period) {
      _OperationLogPeriod.all => '전체 기간',
      _OperationLogPeriod.today => '오늘',
      _OperationLogPeriod.days7 => '최근 7일',
      _OperationLogPeriod.days30 => '최근 30일',
    };
  }

  Widget _periodChip(_OperationLogPeriod period) {
    return ChoiceChip(
      label: Text(_periodLabel(period)),
      selected: _period == period,
      onSelected: (_) => setState(() => _period = period),
    );
  }

  Timestamp? _periodCutoff() {
    final now = DateTime.now();
    return switch (_period) {
      _OperationLogPeriod.all => null,
      _OperationLogPeriod.today => Timestamp.fromDate(
        DateTime(now.year, now.month, now.day),
      ),
      _OperationLogPeriod.days7 => Timestamp.fromDate(
        now.subtract(const Duration(days: 7)),
      ),
      _OperationLogPeriod.days30 => Timestamp.fromDate(
        now.subtract(const Duration(days: 30)),
      ),
    };
  }

  Query<Map<String, dynamic>> _buildAuditQuery() {
    Query<Map<String, dynamic>> query = FirebaseFirestore.instance
        .collection('groups')
        .doc(widget.groupId)
        .collection('auditLogs');
    final cutoff = _periodCutoff();
    if (cutoff != null) {
      query = query.where('at', isGreaterThanOrEqualTo: cutoff);
    }
    return query.orderBy('at', descending: true).limit(200);
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(body: Center(child: Text('로그인이 필요합니다.')));
    }

    final myMemberStream = FirebaseFirestore.instance
        .collection('groups')
        .doc(widget.groupId)
        .collection('members')
        .doc(user.uid)
        .snapshots();
    final auditRef = _buildAuditQuery();

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: myMemberStream,
      builder: (context, memberSnap) {
        if (memberSnap.hasError) {
          return Scaffold(
            appBar: AppBar(
              title: const Row(
                children: [
                  ExcludeSemantics(child: Icon(Icons.history_outlined, size: 18)),
                  SizedBox(width: 6),
                  Text('운영 로그'),
                ],
              ),
            ),
            body: Center(child: Text(friendlyError(memberSnap.error))),
          );
        }
        if (!memberSnap.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final permission = PermissionService.fromMemberData(
          memberSnap.data?.data(),
        );
        if (!permission.canManageRoles()) {
          return Scaffold(
            appBar: AppBar(
              title: const Row(
                children: [
                  ExcludeSemantics(child: Icon(Icons.history_outlined, size: 18)),
                  SizedBox(width: 6),
                  Text('운영 로그'),
                ],
              ),
            ),
            body: const Center(child: Text('권한 관리 권한이 없습니다.')),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: const Row(
              children: [
                Icon(Icons.history_outlined, size: 18),
                SizedBox(width: 6),
                Text('운영 로그'),
              ],
            ),
          ),
          body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: auditRef.snapshots(),
            builder: (context, auditSnap) {
              if (auditSnap.hasError) {
                return Center(child: Text(friendlyError(auditSnap.error)));
              }
              if (!auditSnap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final docs = auditSnap.data!.docs;
              if (docs.isEmpty) {
                return const Center(child: Text('운영 로그가 없습니다.'));
              }
              final filteredDocs = docs.where((doc) {
                final action = doc.data()['action']?.toString() ?? '';
                return _matchesFilter(action);
              }).toList();

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const SectionHeader(
                    title: '운영 로그',
                    icon: Icons.history_outlined,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _filterChip(_OperationLogFilter.all),
                      _filterChip(_OperationLogFilter.role),
                      _filterChip(_OperationLogFilter.member),
                      _filterChip(_OperationLogFilter.invite),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _periodChip(_OperationLogPeriod.all),
                      _periodChip(_OperationLogPeriod.today),
                      _periodChip(_OperationLogPeriod.days7),
                      _periodChip(_OperationLogPeriod.days30),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (filteredDocs.isEmpty)
                    const AppCard(child: Text('선택한 필터에 해당하는 로그가 없습니다.')),
                  for (final doc in filteredDocs) ...[
                    Builder(
                      builder: (context) {
                        final data = doc.data();
                        final action = data['action']?.toString() ?? '-';
                        final actor = data['actorUid']?.toString() ?? '-';
                        final target = data['targetUid']?.toString() ?? '-';
                        final at = data['at'];
                        final atText = at is Timestamp
                            ? formatDate(at.toDate().toLocal())
                            : '-';
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: AppCard(
                            child: ListTile(
                              title: Text(_actionLabel(action)),
                              subtitle: Text(
                                '행위자: $actor / 대상: $target / 시각: $atText\n작업코드: $action',
                              ),
                              isThreeLine: true,
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ],
              );
            },
          ),
        );
      },
    );
  }
}
