import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/app_config.dart';
import '../../services/image_upload_service.dart';
import '../../services/permission_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/helpers.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_snackbar.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/status_badge.dart';

class FinanceScreen extends StatefulWidget {
  const FinanceScreen({super.key, required this.groupId});

  final String groupId;

  @override
  State<FinanceScreen> createState() => _FinanceScreenState();
}

class _FinanceScreenState extends State<FinanceScreen> {
  final Set<String> _ensuredPeriods = <String>{};
  bool _updatingAmount = false;
  bool _bulkUpdating = false;
  final Set<String> _updatingMembers = <String>{};
  final Map<String, String> _accountIdCache = <String, String>{};
  final Map<String, String> _displayNameCache = <String, String>{};

  String get _periodKey => currentPeriodKey();

  DocumentReference<Map<String, dynamic>> get _feeRef => FirebaseFirestore
      .instance
      .collection('groups')
      .doc(widget.groupId)
      .collection('fees')
      .doc(_periodKey);

  Future<void> _ensureMonthlyFeeDocuments(List<String> activeMemberUids) async {
    if (_ensuredPeriods.contains(_periodKey)) return;
    _ensuredPeriods.add(_periodKey);

    try {
      final feeDoc = await _feeRef.get();
      final now = DateTime.now();
      final defaultDueDate = DateTime(now.year, now.month, 25);
      final defaultAmount = _asInt(feeDoc.data()?['amount'], fallback: 0);

      if (!feeDoc.exists) {
        await _feeRef.set({
          'amount': defaultAmount,
          'dueDate': Timestamp.fromDate(defaultDueDate),
          'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      for (final uid in activeMemberUids) {
        final recordRef = _feeRef.collection('records').doc(uid);
        final recordDoc = await recordRef.get();
        if (recordDoc.exists) continue;

        await recordRef.set({
          'status': 'unpaid',
          'paidAt': null,
          'amount': defaultAmount,
        }, SetOptions(merge: true));
      }
    } catch (_) {
      // Keep screen usable even if initialization fails due to permission/race.
    }
  }

  Future<void> _updateMonthlyAmount({
    required BuildContext context,
    required int currentAmount,
    required List<String> unpaidUids,
  }) async {
    if (_updatingAmount) return;

    final controller = TextEditingController(text: '$currentAmount');
    final nextAmount = await showDialog<int>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('월 회비 금액 수정'),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: '금액',
              hintText: '예: 50000',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () {
                final parsed = int.tryParse(controller.text.trim());
                if (parsed == null || parsed < 0) return;
                Navigator.of(ctx).pop(parsed);
              },
              child: const Text('저장'),
            ),
          ],
        );
      },
    );

    if (nextAmount == null) return;
    setState(() => _updatingAmount = true);
    try {
      final batch = FirebaseFirestore.instance.batch();
      batch.set(_feeRef, {'amount': nextAmount}, SetOptions(merge: true));
      for (final uid in unpaidUids) {
        final ref = _feeRef.collection('records').doc(uid);
        batch.set(ref, {'amount': nextAmount}, SetOptions(merge: true));
      }
      await batch.commit();
      if (context.mounted) {
        AppSnackbar.show(
          context,
          message: '월 회비 금액이 업데이트되었습니다.',
          type: AppSnackType.success,
        );
      }
    } on FirebaseException catch (e) {
      if (context.mounted) {
        AppSnackbar.show(
          context,
          message: '금액 수정 실패: ${e.code}',
          type: AppSnackType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _updatingAmount = false);
    }
  }

  Future<void> _togglePaymentStatus({
    required BuildContext context,
    required String uid,
    required bool markAsPaid,
    required int amount,
  }) async {
    if (_updatingMembers.contains(uid)) return;
    setState(() => _updatingMembers.add(uid));
    try {
      await _feeRef.collection('records').doc(uid).set({
        'status': markAsPaid ? 'paid' : 'unpaid',
        'paidAt': markAsPaid ? FieldValue.serverTimestamp() : null,
        'amount': amount,
      }, SetOptions(merge: true));
    } on FirebaseException catch (e) {
      if (context.mounted) {
        AppSnackbar.show(
          context,
          message: '상태 변경 실패: ${e.code}',
          type: AppSnackType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _updatingMembers.remove(uid));
    }
  }

  Future<void> _bulkSetPaymentStatus({
    required BuildContext context,
    required List<_PaymentRow> rows,
    required bool markAsPaid,
  }) async {
    if (_bulkUpdating) return;
    final targets = rows
        .where(
          (row) => markAsPaid ? row.status != 'paid' : row.status != 'unpaid',
        )
        .toList(growable: false);
    if (targets.isEmpty) {
      AppSnackbar.show(
        context,
        message: markAsPaid ? '이미 모두 납부 처리되었습니다.' : '이미 모두 미납 상태입니다.',
        type: AppSnackType.info,
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(markAsPaid ? '일괄 납부 처리' : '일괄 미납 처리'),
        content: Text(
          '${targets.length}명을 ${markAsPaid ? '납부' : '미납'}로 변경할까요?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('변경'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _bulkUpdating = true);
    try {
      final batch = FirebaseFirestore.instance.batch();
      for (final row in targets) {
        final ref = _feeRef.collection('records').doc(row.uid);
        batch.set(ref, {
          'status': markAsPaid ? 'paid' : 'unpaid',
          'paidAt': markAsPaid ? FieldValue.serverTimestamp() : null,
          'amount': row.amount,
        }, SetOptions(merge: true));
      }
      await batch.commit();
      if (!context.mounted) return;
      AppSnackbar.show(
        context,
        message:
            '${targets.length}명을 ${markAsPaid ? '납부 완료' : '미납'} 상태로 변경했습니다.',
        type: AppSnackType.success,
      );
    } on FirebaseException catch (e) {
      if (!context.mounted) return;
      AppSnackbar.show(
        context,
        message: '일괄 상태 변경 실패: ${e.code}',
        type: AppSnackType.error,
      );
    } finally {
      if (mounted) {
        setState(() => _bulkUpdating = false);
      }
    }
  }

  Future<void> _editFeeAccount({
    required BuildContext context,
    required String currentValue,
  }) async {
    final controller = TextEditingController(text: currentValue);
    final nextValue = await showDialog<String>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('회비 계좌 설정'),
          content: TextField(
            controller: controller,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(
              labelText: '회비 계좌',
              hintText: '예) 국민 000000-00-000000',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
              child: const Text('저장'),
            ),
          ],
        );
      },
    );
    controller.dispose();
    if (nextValue == null) return;

    try {
      if (nextValue.isEmpty) {
        await _feeRef.set({
          'bankAccount': FieldValue.delete(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } else {
        await _feeRef.set({
          'bankAccount': nextValue,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
      if (!context.mounted) return;
      AppSnackbar.show(
        context,
        message: '회비 계좌가 저장되었습니다.',
        type: AppSnackType.success,
      );
    } on FirebaseException catch (e) {
      if (!context.mounted) return;
      AppSnackbar.show(
        context,
        message: '회비 계좌 저장 실패: ${e.code}',
        type: AppSnackType.error,
      );
    }
  }

  Future<void> _copyToClipboard({
    required BuildContext context,
    required String value,
    required String successMessage,
  }) async {
    final text = value.trim();
    if (text.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: text));
    if (!context.mounted) return;
    AppSnackbar.show(
      context,
      message: successMessage,
      type: AppSnackType.success,
    );
  }

  Map<String, int> _buildEqualSplitShares({
    required int totalAmount,
    required List<_PaymentRow> members,
  }) {
    if (members.isEmpty || totalAmount <= 0) return const <String, int>{};
    final base = totalAmount ~/ members.length;
    var remainder = totalAmount % members.length;
    final shares = <String, int>{};
    for (final member in members) {
      final amount = base + (remainder > 0 ? 1 : 0);
      shares[member.uid] = amount;
      if (remainder > 0) remainder -= 1;
    }
    return shares;
  }

  Future<void> _openReceiptUrl(String url) async {
    final uri = Uri.tryParse(url.trim());
    if (uri == null) return;
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      AppSnackbar.show(
        context,
        message: '영수증 링크를 열 수 없습니다.',
        type: AppSnackType.error,
      );
    }
  }

  Future<void> _openAddExpenseDialog({
    required BuildContext context,
    required List<_PaymentRow> memberRows,
  }) async {
    final titleController = TextEditingController();
    final amountController = TextEditingController();
    final noteController = TextEditingController();
    final splitControllers = <String, TextEditingController>{
      for (final row in memberRows) row.uid: TextEditingController(),
    };
    var usedAt = DateTime.now();
    var splitEnabled = false;
    var splitMode = 'equal';
    String? validationMessage;
    Uint8List? receiptBytes;
    String? receiptMimeType;
    String? receiptFileName;

    final input = await showDialog<_ExpenseInput>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              title: const Text('회비 사용 내역 등록'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(
                        labelText: '사용 항목',
                        hintText: '예: 장소 대관비',
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: amountController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: '사용 금액',
                        hintText: '예: 50000',
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: noteController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: '비고(선택)',
                        hintText: '메모를 입력해 주세요.',
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        ExcludeSemantics(
                          child: Icon(
                          Icons.calendar_today_outlined,
                          size: 16,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          formatDateOnly(usedAt),
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const Spacer(),
                        OutlinedButton(
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: usedAt,
                              firstDate: DateTime(2020),
                              lastDate: DateTime.now().add(
                                const Duration(days: 365 * 2),
                              ),
                            );
                            if (picked == null) return;
                            setModalState(
                              () => usedAt = DateTime(
                                picked.year,
                                picked.month,
                                picked.day,
                                usedAt.hour,
                                usedAt.minute,
                              ),
                            );
                          },
                          child: const Text('날짜 선택'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      value: splitEnabled,
                      onChanged: (value) =>
                          setModalState(() => splitEnabled = value),
                      title: const Text('경비 분할'),
                      subtitle: const Text('멤버별 분담 금액을 저장합니다.'),
                    ),
                    if (splitEnabled) ...[
                      const SizedBox(height: 6),
                      SegmentedButton<String>(
                        segments: const [
                          ButtonSegment<String>(
                            value: 'equal',
                            icon: Icon(Icons.balance_outlined),
                            label: Text('균등'),
                          ),
                          ButtonSegment<String>(
                            value: 'custom',
                            icon: Icon(Icons.tune_outlined),
                            label: Text('직접 입력'),
                          ),
                        ],
                        selected: {splitMode},
                        onSelectionChanged: (set) {
                          if (set.isEmpty) return;
                          setModalState(() => splitMode = set.first);
                        },
                      ),
                      if (splitMode == 'custom') ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Theme.of(
                                context,
                              ).colorScheme.outlineVariant,
                            ),
                          ),
                          child: Column(
                            children: [
                              for (var i = 0; i < memberRows.length; i++) ...[
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        memberRows[i].nickname,
                                        style: Theme.of(
                                          context,
                                        ).textTheme.bodySmall,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    SizedBox(
                                      width: 120,
                                      child: TextField(
                                        controller:
                                            splitControllers[memberRows[i].uid],
                                        keyboardType: TextInputType.number,
                                        decoration: const InputDecoration(
                                          isDense: true,
                                          hintText: '금액',
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                if (i != memberRows.length - 1)
                                  const SizedBox(height: 6),
                              ],
                            ],
                          ),
                        ),
                      ] else ...[
                        const SizedBox(height: 8),
                        Text(
                          '총액을 인원 수로 자동 균등 분할합니다.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ],
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: AppConfig.enableStorageUpload
                          ? () async {
                              final picked = await ImagePicker().pickImage(
                                source: ImageSource.gallery,
                                maxWidth: 2000,
                                imageQuality: 90,
                              );
                              if (picked == null) return;
                              final bytes = await picked.readAsBytes();
                              if (!context.mounted) return;
                              setModalState(() {
                                receiptBytes = bytes;
                                receiptMimeType = picked.mimeType;
                                receiptFileName = picked.name;
                              });
                            }
                          : null,
                      icon: const Icon(Icons.attach_file_outlined),
                      label: const Text('영수증 첨부'),
                    ),
                    if (!AppConfig.enableStorageUpload) ...[
                      const SizedBox(height: 6),
                      Text(
                        '현재 설정에서는 영수증 첨부를 사용할 수 없습니다.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    if (receiptFileName != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        receiptFileName!,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                    if (validationMessage != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        validationMessage!,
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(color: AppTheme.danger),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('취소'),
                ),
                FilledButton(
                  onPressed: () {
                    final title = titleController.text.trim();
                    final amount = int.tryParse(amountController.text.trim());
                    if (title.isEmpty || amount == null || amount <= 0) {
                      setModalState(
                        () => validationMessage = '사용 항목과 금액을 확인해 주세요.',
                      );
                      return;
                    }

                    Map<String, int> splitShares = const <String, int>{};
                    if (splitEnabled) {
                      if (memberRows.isEmpty) {
                        setModalState(
                          () => validationMessage = '분할할 멤버가 없습니다.',
                        );
                        return;
                      }
                      if (splitMode == 'custom') {
                        splitShares = <String, int>{};
                        for (final row in memberRows) {
                          final raw = splitControllers[row.uid]?.text.trim();
                          if (raw == null || raw.isEmpty) continue;
                          final parsed = int.tryParse(raw);
                          if (parsed == null || parsed < 0) {
                            setModalState(
                              () => validationMessage =
                                  '직접 입력 분할 금액은 0 이상의 숫자만 가능합니다.',
                            );
                            return;
                          }
                          if (parsed > 0) {
                            splitShares[row.uid] = parsed;
                          }
                        }
                        if (splitShares.isEmpty) {
                          setModalState(
                            () => validationMessage = '분할 금액을 1명 이상 입력해 주세요.',
                          );
                          return;
                        }
                        final splitTotal = splitShares.values.fold<int>(
                          0,
                          (acc, value) => acc + value,
                        );
                        if (splitTotal != amount) {
                          setModalState(
                            () => validationMessage =
                                '분할 금액 합계(${_toCurrency(splitTotal)})가 지출 금액(${_toCurrency(amount)})과 일치해야 합니다.',
                          );
                          return;
                        }
                      } else {
                        splitShares = _buildEqualSplitShares(
                          totalAmount: amount,
                          members: memberRows,
                        );
                      }
                    }

                    Navigator.of(ctx).pop(
                      _ExpenseInput(
                        title: title,
                        amount: amount,
                        note: noteController.text.trim(),
                        usedAt: usedAt,
                        splitEnabled: splitEnabled,
                        splitMode: splitEnabled ? splitMode : 'none',
                        splitShares: splitEnabled
                            ? splitShares
                            : const <String, int>{},
                        receiptBytes: receiptBytes,
                        receiptMimeType: receiptMimeType,
                        receiptFileName: receiptFileName,
                      ),
                    );
                  },
                  child: const Text('등록'),
                ),
              ],
            );
          },
        );
      },
    );

    titleController.dispose();
    amountController.dispose();
    noteController.dispose();
    for (final controller in splitControllers.values) {
      controller.dispose();
    }

    if (input == null) return;

    try {
      final expenseRef = _feeRef.collection('expenses').doc();
      String? receiptUrl;
      if (input.receiptBytes != null && input.receiptBytes!.isNotEmpty) {
        if (AppConfig.enableStorageUpload) {
          final uid = FirebaseAuth.instance.currentUser?.uid;
          if (uid != null && uid.isNotEmpty) {
            receiptUrl = await ImageUploadService.uploadExpenseReceipt(
              uid: uid,
              groupId: widget.groupId,
              periodKey: _periodKey,
              expenseId: expenseRef.id,
              bytes: input.receiptBytes!,
              mimeType: input.receiptMimeType,
            );
          }
        } else if (context.mounted) {
          AppSnackbar.show(
            context,
            message: '현재 설정에서는 영수증 첨부가 비활성화되어 있습니다.',
            type: AppSnackType.info,
          );
        }
      }

      await expenseRef.set({
        'title': input.title,
        'amount': input.amount,
        'note': input.note,
        'usedAt': Timestamp.fromDate(input.usedAt),
        'createdBy': FirebaseAuth.instance.currentUser?.uid,
        'createdAt': FieldValue.serverTimestamp(),
        'splitEnabled': input.splitEnabled,
        'splitMode': input.splitMode,
        'splitShares': input.splitShares,
        'splitMemberCount': input.splitShares.length,
        if (receiptUrl != null && receiptUrl.isNotEmpty)
          'receiptUrl': receiptUrl,
      });
      if (!context.mounted) return;
      AppSnackbar.show(
        context,
        message: '회비 사용 내역이 등록되었습니다.',
        type: AppSnackType.success,
      );
    } on FirebaseException catch (e) {
      if (!context.mounted) return;
      AppSnackbar.show(
        context,
        message: '사용 내역 등록 실패: ${e.code}',
        type: AppSnackType.error,
      );
    }
  }

  Future<void> _exportCsv({
    required BuildContext context,
    required List<_PaymentRow> rows,
    required int amount,
  }) async {
    final buffer = StringBuffer()
      ..writeln('period,uid,nickname,status,amount,paidAt')
      ..writeAll(
        rows.map((r) {
          final paidAt = r.paidAt == null ? '' : r.paidAt!.toIso8601String();
          return '$_periodKey,${r.uid},${r.nickname},${r.status},${r.amount},$paidAt';
        }),
        '\n',
      );

    final csv = buffer.toString();
    await Clipboard.setData(ClipboardData(text: csv));
    if (!context.mounted) return;
    AppSnackbar.show(
      context,
      message: 'CSV가 클립보드에 복사되었습니다. (기준금액: $amount원)',
      type: AppSnackType.success,
    );
  }

  Future<Map<String, _MemberIdentity>> _loadMemberIdentities(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> members,
  ) async {
    final memberByUid = <String, Map<String, dynamic>>{
      for (final member in members) member.id: member.data(),
    };
    final uids = memberByUid.keys.toList(growable: false);
    final missing = uids
        .where(
          (uid) =>
              !_accountIdCache.containsKey(uid) ||
              !_displayNameCache.containsKey(uid),
        )
        .toList();
    if (missing.isNotEmpty) {
      for (var i = 0; i < missing.length; i += 30) {
        final end = (i + 30 < missing.length) ? i + 30 : missing.length;
        final chunk = missing.sublist(i, end);
        final snap = await FirebaseFirestore.instance
            .collection('users')
            .where(FieldPath.documentId, whereIn: chunk)
            .get();
        for (final doc in snap.docs) {
          final data = doc.data();
          _accountIdCache[doc.id] = _extractAccountId(data);
          _displayNameCache[doc.id] = _extractUserDisplayName(data);
        }
        for (final uid in chunk) {
          _accountIdCache.putIfAbsent(uid, () => '아이디 없음');
          _displayNameCache.putIfAbsent(
            uid,
            () => _extractMemberDisplayName(memberByUid[uid], uid),
          );
        }
      }
    }
    return {
      for (final uid in uids)
        uid: _MemberIdentity(
          displayName:
              _displayNameCache[uid] ??
              _extractMemberDisplayName(memberByUid[uid], uid),
          accountId: _accountIdCache[uid] ?? '아이디 없음',
        ),
    };
  }

  String _extractUserDisplayName(Map<String, dynamic> data) {
    final displayName = data['displayName']?.toString().trim();
    if (displayName != null && displayName.isNotEmpty) return displayName;
    final nickname = data['nickname']?.toString().trim();
    if (nickname != null && nickname.isNotEmpty) return nickname;
    return '';
  }

  String _extractMemberDisplayName(
    Map<String, dynamic>? data,
    String fallbackUid,
  ) {
    final byDisplayName = data?['displayName']?.toString().trim();
    if (byDisplayName != null && byDisplayName.isNotEmpty) return byDisplayName;
    final byPublic = (data?['public'] as Map?)?['nickname']?.toString().trim();
    if (byPublic != null && byPublic.isNotEmpty) return byPublic;
    final byNickname = data?['nickname']?.toString().trim();
    if (byNickname != null && byNickname.isNotEmpty) return byNickname;
    return fallbackUid;
  }

  String _extractAccountId(Map<String, dynamic> data) {
    final email = data['email']?.toString().trim();
    if (email != null && email.contains('@')) {
      final id = email.split('@').first.trim();
      if (id.isNotEmpty) return id;
    }
    final kakaoId = data['kakaoId']?.toString().trim();
    if (kakaoId != null && kakaoId.isNotEmpty) return 'kakao_$kakaoId';
    final nickname = data['nickname']?.toString().trim();
    if (nickname != null && nickname.isNotEmpty) return nickname;
    final displayName = data['displayName']?.toString().trim();
    if (displayName != null && displayName.isNotEmpty) return displayName;
    return '아이디 없음';
  }

  String _resolveFeeAccount(Map<String, dynamic> fee) {
    const keys = <String>['bankAccount', 'feeAccount', 'account', 'accountNo'];
    for (final key in keys) {
      final value = fee[key]?.toString().trim();
      if (value != null && value.isNotEmpty) return value;
    }
    return '';
  }

  // -- UI builder helpers --

  Widget _buildMetricTile({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(6),
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 14, color: colorScheme.primary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: valueColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBankAccountSection({
    required String feeAccount,
    required bool hasFeeAccount,
    required bool canEdit,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colorScheme.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: colorScheme.primary.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          ExcludeSemantics(
            child: Icon(
            Icons.account_balance_outlined,
            size: 16,
            color: colorScheme.primary,
          ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '회비 계좌',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                SelectableText(
                  hasFeeAccount ? feeAccount : '미등록',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: hasFeeAccount ? null : colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          if (hasFeeAccount)
            _buildIconAction(
              icon: Icons.copy_rounded,
              tooltip: '계좌 복사',
              onPressed: () => _copyToClipboard(
                context: context,
                value: feeAccount,
                successMessage: '회비 계좌가 복사되었습니다.',
              ),
            ),
          if (canEdit) ...[
            const SizedBox(width: 4),
            _buildIconAction(
              icon: Icons.edit_note_outlined,
              tooltip: '계좌 수정',
              onPressed: () =>
                  _editFeeAccount(context: context, currentValue: feeAccount),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildIconAction({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Semantics(
      label: tooltip,
      button: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onPressed,
        child: Tooltip(
          message: tooltip,
          child: Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(6)),
            child: ExcludeSemantics(child: Icon(icon, size: 18, color: colorScheme.onSurfaceVariant)),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle({
    required IconData icon,
    required String title,
    Widget? trailing,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          ExcludeSemantics(child: Icon(icon, size: 16, color: colorScheme.onSurfaceVariant)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          if (trailing != null) trailing,
        ],
      ),
    );
  }

  Widget _buildMemberRow({
    required _PaymentRow row,
    required bool canEdit,
    required bool isLast,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final isPaid = row.status == 'paid';
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6),
                ),
                alignment: Alignment.center,
                child: Text(
                  row.nickname.isNotEmpty ? row.nickname.characters.first : '?',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      row.nickname,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          row.accountId,
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(color: colorScheme.onSurfaceVariant),
                        ),
                        if (row.paidAt != null) ...[
                          const SizedBox(width: 6),
                          ExcludeSemantics(
                            child: Icon(
                            Icons.schedule,
                            size: 11,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          ),
                          const SizedBox(width: 3),
                          Text(
                            formatDateOnly(row.paidAt!),
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(color: colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _toCurrency(row.amount),
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  StatusBadge(
                    label: isPaid ? '납부' : '미납',
                    tone: isPaid
                        ? StatusBadgeTone.success
                        : StatusBadgeTone.warning,
                  ),
                ],
              ),
            ],
          ),
        ),
        if (canEdit)
          Padding(
            padding: const EdgeInsets.only(left: 42, bottom: 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: _buildPaymentActionChip(
                isPaid: isPaid,
                saving: _updatingMembers.contains(row.uid),
                onTap: () => _togglePaymentStatus(
                  context: context,
                  uid: row.uid,
                  markAsPaid: !isPaid,
                  amount: row.amount,
                ),
              ),
            ),
          ),
        if (!isLast)
          Divider(
            height: 1,
            color: colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
      ],
    );
  }

  Widget _buildPaymentActionChip({
    required bool isPaid,
    required bool saving,
    required VoidCallback onTap,
  }) {
    return Semantics(
      label: isPaid ? '미납 처리' : '납부 처리',
      button: true,
      child: InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: saving ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isPaid
              ? AppTheme.danger.withValues(alpha: 0.08)
              : AppTheme.success.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isPaid
                ? AppTheme.danger.withValues(alpha: 0.3)
                : AppTheme.success.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (saving)
              SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  color: isPaid ? AppTheme.danger : AppTheme.success,
                ),
              )
            else
              ExcludeSemantics(
                child: Icon(
                  isPaid ? Icons.undo : Icons.check,
                  size: 14,
                  color: isPaid ? AppTheme.danger : AppTheme.success,
                ),
              ),
            const SizedBox(width: 6),
            Text(
              isPaid ? '미납 처리' : '납부 처리',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: isPaid ? AppTheme.danger : AppTheme.success,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    ),
    );
  }

  Widget _buildExpenseRow(_ExpenseRow expense, {required bool isLast}) {
    final colorScheme = Theme.of(context).colorScheme;
    final splitTotal = expense.splitShares.values.fold<int>(
      0,
      (acc, value) => acc + value,
    );
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppTheme.warning.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    alignment: Alignment.center,
                    child: const ExcludeSemantics(
                      child: Icon(
                      Icons.receipt_outlined,
                      size: 14,
                      color: AppTheme.warning,
                    ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          expense.title,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            ExcludeSemantics(
                              child: Icon(
                              Icons.calendar_today_outlined,
                              size: 11,
                              color: colorScheme.onSurfaceVariant,
                            ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              formatDateOnly(expense.usedAt),
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                            ),
                            if (expense.note.isNotEmpty) ...[
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  expense.note,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.labelSmall
                                      ?.copyWith(
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '-${_toCurrency(expense.amount)}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppTheme.danger,
                        ),
                      ),
                      if (expense.receiptUrl.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Semantics(
                          label: '영수증 보기',
                          button: true,
                          child: InkWell(
                          borderRadius: BorderRadius.circular(6),
                          onTap: () => _openReceiptUrl(expense.receiptUrl),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: colorScheme.primary.withValues(
                                alpha: 0.08,
                              ),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ExcludeSemantics(
                                  child: Icon(
                                  Icons.image_outlined,
                                  size: 12,
                                  color: colorScheme.primary,
                                ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '영수증',
                                  style: Theme.of(context).textTheme.labelSmall
                                      ?.copyWith(
                                        color: colorScheme.primary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
              if (expense.splitEnabled && expense.splitShares.isNotEmpty) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      StatusBadge(
                        label: expense.splitMode == 'custom'
                            ? '직접 분할 ${expense.splitShares.length}명'
                            : '균등 분할 ${expense.splitShares.length}명',
                        tone: StatusBadgeTone.primary,
                      ),
                      StatusBadge(
                        label: '분할 합계 ${_toCurrency(splitTotal)}',
                        tone: splitTotal == expense.amount
                            ? StatusBadgeTone.success
                            : StatusBadgeTone.warning,
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        if (!isLast)
          Divider(
            height: 1,
            color: colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(body: Center(child: Text('로그인이 필요합니다.')));
    }

    final colorScheme = Theme.of(context).colorScheme;
    final myMemberStream = FirebaseFirestore.instance
        .collection('groups')
        .doc(widget.groupId)
        .collection('members')
        .doc(user.uid)
        .snapshots();
    final activeMembersStream = FirebaseFirestore.instance
        .collection('groups')
        .doc(widget.groupId)
        .collection('members')
        .where('status', isEqualTo: 'active')
        .snapshots();
    final recordsStream = _feeRef.collection('records').snapshots();
    final expensesStream = _feeRef
        .collection('expenses')
        .orderBy('usedAt', descending: true)
        .limit(100)
        .snapshots();
    final feeDocStream = _feeRef.snapshots();

    return Scaffold(
      appBar: AppBar(title: const Text('회비 관리')),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: myMemberStream,
        builder: (context, myMemberSnap) {
          final permission = PermissionService.fromMemberData(
            myMemberSnap.data?.data(),
          );
          final canEdit = permission.canManageFinance();

          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: activeMembersStream,
            builder: (context, memberSnap) {
              return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: recordsStream,
                builder: (context, recordSnap) {
                  return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                    stream: feeDocStream,
                    builder: (context, feeSnap) {
                      return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: expensesStream,
                        builder: (context, expenseSnap) {
                          if (memberSnap.hasError ||
                              recordSnap.hasError ||
                              feeSnap.hasError ||
                              expenseSnap.hasError) {
                            return Center(
                              child: Text(
                                friendlyError(
                                  memberSnap.error ??
                                      recordSnap.error ??
                                      feeSnap.error ??
                                      expenseSnap.error,
                                ),
                              ),
                            );
                          }
                          if (!memberSnap.hasData ||
                              !recordSnap.hasData ||
                              !feeSnap.hasData ||
                              !expenseSnap.hasData) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }

                          final members = memberSnap.data!.docs;
                          final memberUids = members.map((d) => d.id).toList();
                          _ensureMonthlyFeeDocuments(memberUids);

                          final fee =
                              feeSnap.data!.data() ?? <String, dynamic>{};
                          final monthAmount = _asInt(
                            fee['amount'],
                            fallback: 0,
                          );
                          final dueDateTs = fee['dueDate'];
                          final dueDateText = dueDateTs is Timestamp
                              ? formatDateOnly(dueDateTs.toDate())
                              : '-';
                          final feeAccount = _resolveFeeAccount(fee);
                          final hasFeeAccount = feeAccount.isNotEmpty;

                          final recordByUid = <String, Map<String, dynamic>>{
                            for (final d in recordSnap.data!.docs)
                              d.id: d.data(),
                          };

                          final rows = <_PaymentRow>[];
                          var paidCount = 0;
                          var unpaidCount = 0;
                          final unpaidUids = <String>[];

                          for (final m in members) {
                            final data = m.data();
                            final record =
                                recordByUid[m.id] ?? const <String, dynamic>{};
                            final nickname =
                                data['public']?['nickname']?.toString() ??
                                data['displayName']?.toString() ??
                                m.id;
                            final status =
                                record['status']?.toString() ?? 'unpaid';
                            final amount = _asInt(
                              record['amount'],
                              fallback: monthAmount,
                            );
                            final paidAtRaw = record['paidAt'];
                            final paidAt = paidAtRaw is Timestamp
                                ? paidAtRaw.toDate()
                                : null;

                            if (status == 'paid') {
                              paidCount++;
                            } else {
                              unpaidCount++;
                              unpaidUids.add(m.id);
                            }

                            rows.add(
                              _PaymentRow(
                                uid: m.id,
                                nickname: nickname,
                                accountId: '아이디 확인 중',
                                status: status,
                                amount: amount,
                                paidAt: paidAt,
                              ),
                            );
                          }

                          if (rows.isEmpty) {
                            return const EmptyState(
                              icon: Icons.group_off_outlined,
                              title: '활성 멤버가 없습니다',
                              description: '활성 멤버가 있어야 회비 관리가 가능합니다.',
                            );
                          }

                          rows.sort((a, b) {
                            if (a.status == b.status) {
                              return a.nickname.compareTo(b.nickname);
                            }
                            if (a.status == 'unpaid') return -1;
                            return 1;
                          });

                          final expenses = <_ExpenseRow>[];
                          for (final doc in expenseSnap.data!.docs) {
                            final data = doc.data();
                            final title = data['title']?.toString().trim();
                            final amount = _asInt(data['amount'], fallback: 0);
                            final usedAtRaw = data['usedAt'];
                            final usedAt = usedAtRaw is Timestamp
                                ? usedAtRaw.toDate()
                                : DateTime.now();
                            final note = data['note']?.toString().trim() ?? '';
                            final receiptUrl =
                                data['receiptUrl']?.toString().trim() ?? '';
                            final splitEnabled = data['splitEnabled'] == true;
                            final splitMode =
                                data['splitMode']?.toString() ?? 'none';
                            final rawSplitShares = data['splitShares'];
                            final splitShares = <String, int>{};
                            if (rawSplitShares is Map) {
                              rawSplitShares.forEach((key, value) {
                                final uid = key.toString();
                                final share = _asInt(value, fallback: 0);
                                if (uid.isNotEmpty && share > 0) {
                                  splitShares[uid] = share;
                                }
                              });
                            }
                            if (amount <= 0) continue;
                            expenses.add(
                              _ExpenseRow(
                                title: (title != null && title.isNotEmpty)
                                    ? title
                                    : '사용 내역',
                                amount: amount,
                                usedAt: usedAt,
                                note: note,
                                receiptUrl: receiptUrl,
                                splitEnabled: splitEnabled,
                                splitMode: splitMode,
                                splitShares: splitShares,
                              ),
                            );
                          }
                          expenses.sort((a, b) => b.usedAt.compareTo(a.usedAt));

                          final totalPaidAmount = rows
                              .where((row) => row.status == 'paid')
                              .fold<int>(0, (total, row) => total + row.amount);
                          final totalExpenseAmount = expenses.fold<int>(
                            0,
                            (total, row) => total + row.amount,
                          );
                          final balanceAmount =
                              totalPaidAmount - totalExpenseAmount;
                          final totalMembers = rows.length;
                          final paymentRate = totalMembers > 0
                              ? paidCount / totalMembers
                              : 0.0;

                          return FutureBuilder<Map<String, _MemberIdentity>>(
                            future: _loadMemberIdentities(members),
                            builder: (context, identitySnap) {
                              final identities =
                                  identitySnap.data ??
                                  const <String, _MemberIdentity>{};
                              final displayRows = rows
                                  .map(
                                    (row) => row.copyWith(
                                      nickname:
                                          identities[row.uid]?.displayName ??
                                          row.nickname,
                                      accountId:
                                          identities[row.uid]?.accountId ??
                                          '아이디 없음',
                                    ),
                                  )
                                  .toList();
                              _PaymentRow? myDisplayRow;
                              for (final row in displayRows) {
                                if (row.uid == user.uid) {
                                  myDisplayRow = row;
                                  break;
                                }
                              }
                              return ListView(
                                padding: const EdgeInsets.all(16),
                                children: [
                                  // -- 이번 달 요약 카드 --
                                  AppCard(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        // 기간 + 납부기한
                                        Row(
                                          children: [
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 10,
                                                    vertical: 5,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: colorScheme.primary
                                                    .withValues(alpha: 0.08),
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    Icons
                                                        .calendar_month_outlined,
                                                    size: 14,
                                                    color: colorScheme.primary,
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Text(
                                                    _periodKey,
                                                    style: Theme.of(context)
                                                        .textTheme
                                                        .labelMedium
                                                        ?.copyWith(
                                                          color: colorScheme
                                                              .primary,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                        ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              '납부기한 $dueDateText',
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .labelSmall
                                                  ?.copyWith(
                                                    color: colorScheme
                                                        .onSurfaceVariant,
                                                  ),
                                            ),
                                            const Spacer(),
                                            if (canEdit)
                                              _buildIconAction(
                                                icon: Icons.edit_outlined,
                                                tooltip: '월 회비 금액 수정',
                                                onPressed: _updatingAmount
                                                    ? () {}
                                                    : () =>
                                                          _updateMonthlyAmount(
                                                            context: context,
                                                            currentAmount:
                                                                monthAmount,
                                                            unpaidUids:
                                                                unpaidUids,
                                                          ),
                                              ),
                                          ],
                                        ),
                                        const SizedBox(height: 16),

                                        // 월 회비 금액 (large)
                                        Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.baseline,
                                          textBaseline: TextBaseline.alphabetic,
                                          children: [
                                            Text(
                                              _toCurrency(monthAmount),
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .headlineMedium
                                                  ?.copyWith(
                                                    fontWeight: FontWeight.w700,
                                                    color: AppTheme.primary,
                                                  ),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              '/ 월',
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodySmall
                                                  ?.copyWith(
                                                    color: colorScheme
                                                        .onSurfaceVariant,
                                                  ),
                                            ),
                                          ],
                                        ),

                                        if (canEdit) ...[
                                          const SizedBox(height: 12),
                                          // 납부 진행률
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  '납부율',
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .labelSmall
                                                      ?.copyWith(
                                                        color: colorScheme
                                                            .onSurfaceVariant,
                                                      ),
                                                ),
                                              ),
                                              Text(
                                                '$paidCount / $totalMembers명',
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .labelSmall
                                                    ?.copyWith(
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 6),
                                          ClipRRect(
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                            child: LinearProgressIndicator(
                                              value: paymentRate,
                                              minHeight: 6,
                                              backgroundColor: colorScheme
                                                  .surfaceContainerHighest,
                                              valueColor:
                                                  const AlwaysStoppedAnimation(
                                                    AppTheme.success,
                                                  ),
                                            ),
                                          ),
                                          const SizedBox(height: 14),
                                          // 메트릭 그리드
                                          Row(
                                            children: [
                                              Expanded(
                                                child: _buildMetricTile(
                                                  icon: Icons
                                                      .check_circle_outline,
                                                  label: '납부 완료',
                                                  value: '$paidCount명',
                                                  valueColor: AppTheme.success,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: _buildMetricTile(
                                                  icon: Icons.pending_outlined,
                                                  label: '미납',
                                                  value: '$unpaidCount명',
                                                  valueColor: AppTheme.warning,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          Row(
                                            children: [
                                              Expanded(
                                                child: _buildMetricTile(
                                                  icon: Icons.savings_outlined,
                                                  label: '총 납부액',
                                                  value: _toCurrency(
                                                    totalPaidAmount,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: _buildMetricTile(
                                                  icon: Icons
                                                      .account_balance_wallet_outlined,
                                                  label: '잔액',
                                                  value: _toCurrency(
                                                    balanceAmount,
                                                  ),
                                                  valueColor: balanceAmount >= 0
                                                      ? AppTheme.primary
                                                      : AppTheme.danger,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ] else ...[
                                          // 일반 멤버: 내 납부 상태
                                          if (myDisplayRow != null) ...[
                                            const SizedBox(height: 14),
                                            Container(
                                              width: double.infinity,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 12,
                                                    vertical: 10,
                                                  ),
                                              decoration: BoxDecoration(
                                                color:
                                                    myDisplayRow.status ==
                                                        'paid'
                                                    ? AppTheme.success
                                                          .withValues(
                                                            alpha: 0.08,
                                                          )
                                                    : AppTheme.warning
                                                          .withValues(
                                                            alpha: 0.08,
                                                          ),
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                              ),
                                              child: Row(
                                                children: [
                                                  Icon(
                                                    myDisplayRow.status ==
                                                            'paid'
                                                        ? Icons.check_circle
                                                        : Icons.info_outline,
                                                    size: 16,
                                                    color:
                                                        myDisplayRow.status ==
                                                            'paid'
                                                        ? AppTheme.success
                                                        : AppTheme.warning,
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Expanded(
                                                    child: Text(
                                                      myDisplayRow.status ==
                                                              'paid'
                                                          ? '이번 달 회비를 납부했습니다.'
                                                          : '이번 달 회비가 아직 미납입니다.',
                                                      style: Theme.of(context)
                                                          .textTheme
                                                          .bodyMedium
                                                          ?.copyWith(
                                                            fontWeight:
                                                                FontWeight.w600,
                                                            color:
                                                                myDisplayRow
                                                                        .status ==
                                                                    'paid'
                                                                ? AppTheme
                                                                      .success
                                                                : AppTheme
                                                                      .warning,
                                                          ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                          const SizedBox(height: 12),
                                          // 일반 멤버도 사용/잔액은 볼 수 있음
                                          Row(
                                            children: [
                                              Expanded(
                                                child: _buildMetricTile(
                                                  icon: Icons.receipt_outlined,
                                                  label: '회비 사용',
                                                  value: _toCurrency(
                                                    totalExpenseAmount,
                                                  ),
                                                  valueColor: AppTheme.warning,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: _buildMetricTile(
                                                  icon: Icons
                                                      .account_balance_wallet_outlined,
                                                  label: '잔액',
                                                  value: _toCurrency(
                                                    balanceAmount,
                                                  ),
                                                  valueColor: balanceAmount >= 0
                                                      ? AppTheme.primary
                                                      : AppTheme.danger,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                        const SizedBox(height: 14),
                                        // 계좌 정보
                                        _buildBankAccountSection(
                                          feeAccount: feeAccount,
                                          hasFeeAccount: hasFeeAccount,
                                          canEdit: canEdit,
                                        ),
                                      ],
                                    ),
                                  ),

                                  // -- 멤버 납부 목록 (관리자) --
                                  if (canEdit) ...[
                                    const SizedBox(height: 8),
                                    AppCard(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          _buildSectionTitle(
                                            icon: Icons.people_outline,
                                            title:
                                                '멤버 납부 목록 ($paidCount/$totalMembers)',
                                            trailing: Semantics(
                                              label: 'CSV 다운로드',
                                              button: true,
                                              child: InkWell(
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                              onTap: () => _exportCsv(
                                                context: context,
                                                rows: displayRows,
                                                amount: monthAmount,
                                              ),
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 10,
                                                      vertical: 5,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: colorScheme.primary
                                                      .withValues(alpha: 0.06),
                                                  borderRadius:
                                                      BorderRadius.circular(6),
                                                ),
                                                child: Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    ExcludeSemantics(
                                                      child: Icon(
                                                      Icons.download_outlined,
                                                      size: 14,
                                                      color:
                                                          colorScheme.primary,
                                                    ),
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      'CSV',
                                                      style: Theme.of(context)
                                                          .textTheme
                                                          .labelSmall
                                                          ?.copyWith(
                                                            color: colorScheme
                                                                .primary,
                                                            fontWeight:
                                                                FontWeight.w600,
                                                          ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                          ),
                                          const SizedBox(height: 4),
                                          Wrap(
                                            spacing: 8,
                                            runSpacing: 8,
                                            children: [
                                              OutlinedButton.icon(
                                                onPressed: _bulkUpdating
                                                    ? null
                                                    : () =>
                                                          _bulkSetPaymentStatus(
                                                            context: context,
                                                            rows: displayRows,
                                                            markAsPaid: true,
                                                          ),
                                                icon: const ExcludeSemantics(child: Icon(
                                                  Icons.check_circle_outline,
                                                  size: 16,
                                                )),
                                                label: const Text('전체 납부 처리'),
                                              ),
                                              OutlinedButton.icon(
                                                onPressed: _bulkUpdating
                                                    ? null
                                                    : () =>
                                                          _bulkSetPaymentStatus(
                                                            context: context,
                                                            rows: displayRows,
                                                            markAsPaid: false,
                                                          ),
                                                icon: const ExcludeSemantics(child: Icon(
                                                  Icons.undo_outlined,
                                                  size: 16,
                                                )),
                                                label: const Text('전체 미납 처리'),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          for (
                                            var i = 0;
                                            i < displayRows.length;
                                            i++
                                          )
                                            _buildMemberRow(
                                              row: displayRows[i],
                                              canEdit: canEdit,
                                              isLast:
                                                  i == displayRows.length - 1,
                                            ),
                                        ],
                                      ),
                                    ),
                                  ],

                                  // -- 회비 사용 내역 --
                                  const SizedBox(height: 8),
                                  AppCard(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        _buildSectionTitle(
                                          icon: Icons.receipt_long_outlined,
                                          title: '회비 사용 내역',
                                          trailing: canEdit
                                              ? Semantics(
                                                  label: '지출 항목 등록',
                                                  button: true,
                                                  child: InkWell(
                                                  borderRadius:
                                                      BorderRadius.circular(6),
                                                  onTap: () =>
                                                      _openAddExpenseDialog(
                                                        context: context,
                                                        memberRows: displayRows,
                                                      ),
                                                  child: Container(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 10,
                                                          vertical: 5,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color: colorScheme.primary
                                                          .withValues(
                                                            alpha: 0.06,
                                                          ),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            6,
                                                          ),
                                                    ),
                                                    child: Row(
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      children: [
                                                        ExcludeSemantics(
                                                          child: Icon(
                                                          Icons.add,
                                                          size: 14,
                                                          color: colorScheme
                                                              .primary,
                                                        ),
                                                        ),
                                                        const SizedBox(
                                                          width: 4,
                                                        ),
                                                        Text(
                                                          '등록',
                                                          style: Theme.of(context)
                                                              .textTheme
                                                              .labelSmall
                                                              ?.copyWith(
                                                                color:
                                                                    colorScheme
                                                                        .primary,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600,
                                                              ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                )
                                              )
                                              : null,
                                        ),
                                        if (expenses.isEmpty)
                                          Padding(
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 20,
                                            ),
                                            child: Center(
                                              child: Column(
                                                children: [
                                                  ExcludeSemantics(
                                                    child: Icon(
                                                    Icons.receipt_long_outlined,
                                                    size: 32,
                                                    color: colorScheme
                                                        .onSurfaceVariant
                                                        .withValues(alpha: 0.4),
                                                  ),
                                                  ),
                                                  const SizedBox(height: 8),
                                                  Text(
                                                    '등록된 사용 내역이 없습니다.',
                                                    style: Theme.of(context)
                                                        .textTheme
                                                        .bodySmall
                                                        ?.copyWith(
                                                          color: colorScheme
                                                              .onSurfaceVariant,
                                                        ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        for (
                                          var i = 0;
                                          i < expenses.length;
                                          i++
                                        )
                                          _buildExpenseRow(
                                            expenses[i],
                                            isLast: i == expenses.length - 1,
                                          ),
                                        if (expenses.isNotEmpty) ...[
                                          const SizedBox(height: 8),
                                          Divider(
                                            height: 1,
                                            color: colorScheme.outlineVariant,
                                          ),
                                          const SizedBox(height: 8),
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.end,
                                            children: [
                                              Text(
                                                '총 사용  ',
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .labelSmall
                                                    ?.copyWith(
                                                      color: colorScheme
                                                          .onSurfaceVariant,
                                                    ),
                                              ),
                                              Text(
                                                _toCurrency(totalExpenseAmount),
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .bodyMedium
                                                    ?.copyWith(
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      color: AppTheme.danger,
                                                    ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),

                                  // -- 일반 멤버 권한 안내 --
                                  if (!canEdit)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 12),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 10,
                                        ),
                                        decoration: BoxDecoration(
                                          color: colorScheme
                                              .surfaceContainerHighest
                                              .withValues(alpha: 0.4),
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            ExcludeSemantics(
                                              child: Icon(
                                              Icons.lock_outline,
                                              size: 14,
                                              color:
                                                  colorScheme.onSurfaceVariant,
                                            ),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                '회계 수정 권한이 없어 조회만 가능합니다.',
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .labelSmall
                                                    ?.copyWith(
                                                      color: colorScheme
                                                          .onSurfaceVariant,
                                                    ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  const SizedBox(height: 16),
                                ],
                              );
                            },
                          );
                        },
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _PaymentRow {
  const _PaymentRow({
    required this.uid,
    required this.nickname,
    required this.accountId,
    required this.status,
    required this.amount,
    required this.paidAt,
  });

  final String uid;
  final String nickname;
  final String accountId;
  final String status;
  final int amount;
  final DateTime? paidAt;

  _PaymentRow copyWith({
    String? uid,
    String? nickname,
    String? accountId,
    String? status,
    int? amount,
    DateTime? paidAt,
  }) {
    return _PaymentRow(
      uid: uid ?? this.uid,
      nickname: nickname ?? this.nickname,
      accountId: accountId ?? this.accountId,
      status: status ?? this.status,
      amount: amount ?? this.amount,
      paidAt: paidAt ?? this.paidAt,
    );
  }
}

class _ExpenseInput {
  const _ExpenseInput({
    required this.title,
    required this.amount,
    required this.note,
    required this.usedAt,
    required this.splitEnabled,
    required this.splitMode,
    required this.splitShares,
    this.receiptBytes,
    this.receiptMimeType,
    this.receiptFileName,
  });

  final String title;
  final int amount;
  final String note;
  final DateTime usedAt;
  final bool splitEnabled;
  final String splitMode;
  final Map<String, int> splitShares;
  final Uint8List? receiptBytes;
  final String? receiptMimeType;
  final String? receiptFileName;
}

class _ExpenseRow {
  const _ExpenseRow({
    required this.title,
    required this.amount,
    required this.usedAt,
    required this.note,
    required this.receiptUrl,
    required this.splitEnabled,
    required this.splitMode,
    required this.splitShares,
  });

  final String title;
  final int amount;
  final DateTime usedAt;
  final String note;
  final String receiptUrl;
  final bool splitEnabled;
  final String splitMode;
  final Map<String, int> splitShares;
}

class _MemberIdentity {
  const _MemberIdentity({required this.displayName, required this.accountId});

  final String displayName;
  final String accountId;
}

int _asInt(dynamic value, {required int fallback}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? fallback;
  return fallback;
}

String _toCurrency(int amount) {
  final text = amount.toString();
  final reg = RegExp(r'\B(?=(\d{3})+(?!\d))');
  return '${text.replaceAll(reg, ',')}원';
}
