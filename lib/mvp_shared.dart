import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class MvpStatus {
  static const open = 'open';
  static const applied = 'applied';
  static const approved = 'approved';
  static const rejected = 'rejected';
  static const cancelled = 'cancelled';
  static const completed = 'completed';

  static String request(dynamic raw) {
    final value = raw?.toString().trim();
    switch (value) {
      case 'approved':
      case '승인':
        return approved;
      case 'rejected':
      case '거절':
      case 'closed':
        return rejected;
      case 'cancelled':
      case 'canceled':
      case '취소':
        return cancelled;
      case 'completed':
      case '완료':
        return completed;
      case 'applied':
        return applied;
      case 'requested':
      case '대기':
      case 'open':
      case null:
      case '':
        return open;
      default:
        return open;
    }
  }

  static String application(dynamic raw) {
    final value = raw?.toString().trim();
    switch (value) {
      case 'approved':
      case '승인':
        return approved;
      case 'rejected':
      case '거절':
      case 'closed':
        return rejected;
      case 'completed':
      case '완료':
        return completed;
      case 'applied':
      case 'requested':
      case '대기':
      case 'open':
      case null:
      case '':
        return applied;
      default:
        return applied;
    }
  }

  static String label(String status) {
    switch (status) {
      case open:
        return '모집중';
      case applied:
        return '지원함';
      case approved:
        return '승인됨';
      case rejected:
        return '미선정';
      case cancelled:
        return '취소됨';
      case completed:
        return '완료';
      default:
        return '확인 필요';
    }
  }

  static Color color(String status) {
    switch (status) {
      case open:
        return const Color(0xFF2C7A7B);
      case applied:
        return const Color(0xFFB7791F);
      case approved:
        return const Color(0xFF2F855A);
      case rejected:
        return const Color(0xFFC53030);
      case cancelled:
        return const Color(0xFF718096);
      case completed:
        return const Color(0xFF4A5568);
      default:
        return const Color(0xFF718096);
    }
  }
}

class StatusChip extends StatelessWidget {
  const StatusChip(this.status, {super.key, this.label});

  final String status;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final chipColor = MvpStatus.color(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: chipColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: chipColor.withValues(alpha: 0.28)),
      ),
      child: Text(
        label ?? MvpStatus.label(status),
        style: TextStyle(
          color: chipColor,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.title,
    required this.message,
    this.icon = Icons.inbox_outlined,
  });

  final String title;
  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 42, color: theme.colorScheme.primary),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.grey.shade700,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

bool isManagerRole(String? role) => role == 'manager' || role == 'admin';

String roleLabel(String? role) {
  if (isManagerRole(role)) return '매니저';
  return '알바생';
}

String requestOwnerId(Map<String, dynamic> data) {
  return (data['requesterId'] ?? data['userId'] ?? '').toString();
}

String requestOwnerName(Map<String, dynamic> data) {
  final name = data['requesterName'] ?? data['userName'] ?? '알바생';
  return name.toString();
}

DateTime? asDateTime(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  return null;
}

String dateKey(DateTime date) {
  return DateFormat('yyyy-MM-dd').format(date);
}

DateTime combineDateAndTime(DateTime date, TimeOfDay time) {
  return DateTime(date.year, date.month, date.day, time.hour, time.minute);
}

String formatDate(dynamic value) {
  final date = asDateTime(value);
  if (date == null) return '날짜 미정';
  return DateFormat('M월 d일 (E)', 'ko').format(date);
}

String formatTime(dynamic value) {
  final date = asDateTime(value);
  if (date == null) return '시간 미정';
  return DateFormat('a h:mm', 'ko').format(date);
}

String formatDateTime(dynamic value) {
  final date = asDateTime(value);
  if (date == null) return '일정 미정';
  return DateFormat('M월 d일 (E) a h:mm', 'ko').format(date);
}

String formatTimeRange(Map<String, dynamic> data) {
  return '${formatDate(data['startTime'])} ${formatTime(data['startTime'])} - ${formatTime(data['endTime'])}';
}

String cleanError(Object error) {
  return error.toString().replaceFirst('Exception: ', '');
}
