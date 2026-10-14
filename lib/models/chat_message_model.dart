import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';

enum ChatRole { user, bot }

class ChatMessageModel {
  final String id;
  final ChatRole role;
  final String content;
  final DateTime timestamp;

  ChatMessageModel({
    String? id,
    required this.role,
    required this.content,
    DateTime? timestamp,
  })  : id = id ?? DateTime.now().microsecondsSinceEpoch.toString(),
        timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'role': role == ChatRole.user ? 'user' : 'bot',
        'content': content,
        'timestamp': timestamp.toIso8601String(),
      };

  factory ChatMessageModel.fromJson(Map<String, dynamic> json) => ChatMessageModel(
        id: json['id'] as String?,
        role: (json['role'] as String?) == 'user' ? ChatRole.user : ChatRole.bot,
        content: (json['content'] as String?) ?? '',
        timestamp: json['timestamp'] != null
            ? DateTime.tryParse(json['timestamp'].toString()) ?? DateTime.now()
            : (json['created_at'] != null
                ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
                : DateTime.now()),
      );
}

class ChatSessionModel {
  final String id;
  String title;
  String category;
  DateTime updatedAt;
  final List<ChatMessageModel> messages;

  ChatSessionModel({
    required this.id,
    required this.title,
    required this.category,
    required this.updatedAt,
    required this.messages,
  });

  static String detectCategory(String text) {
    final lower = text.toLowerCase();
    if (lower.contains('cse') ||
        lower.contains('stock') ||
        lower.contains('share') ||
        lower.contains('aspi') ||
        lower.contains('sl20') ||
        lower.contains('dividend') ||
        lower.contains('jkh') ||
        lower.contains('comb') ||
        lower.contains('equity') ||
        lower.contains('market')) {
      return 'CSE & Stocks';
    } else if (lower.contains('deposit') ||
        lower.contains('fd') ||
        lower.contains('t-bill') ||
        lower.contains('treasury') ||
        lower.contains('bond') ||
        lower.contains('interest') ||
        lower.contains('yield') ||
        lower.contains('boc') ||
        lower.contains('commercial bank')) {
      return 'Fixed Income & Rates';
    } else if (lower.contains('budget') ||
        lower.contains('50/30/20') ||
        lower.contains('expense') ||
        lower.contains('spend') ||
        lower.contains('save') ||
        lower.contains('savings') ||
        lower.contains('debt') ||
        lower.contains('loan') ||
        lower.contains('goal')) {
      return 'Budget & Expenses';
    } else if (lower.contains('epf') ||
        lower.contains('etf') ||
        lower.contains('tax') ||
        lower.contains('wht') ||
        lower.contains('apit') ||
        lower.contains('pension') ||
        lower.contains('salary')) {
      return 'EPF, ETF & Taxes';
    }
    return 'General Advisory';
  }

  String get timeCategory {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final sessionDay = DateTime(updatedAt.year, updatedAt.month, updatedAt.day);

    final diffDays = today.difference(sessionDay).inDays;
    if (diffDays == 0) {
      return 'Today';
    } else if (diffDays == 1) {
      return 'Yesterday';
    } else if (diffDays <= 7) {
      return 'Previous 7 Days';
    } else if (now.year == updatedAt.year && now.month == updatedAt.month) {
      return 'This Month';
    } else {
      return 'Earlier';
    }
  }

  IconData get categoryIcon {
    switch (category) {
      case 'CSE & Stocks':
        return Icons.trending_up_rounded;
      case 'Fixed Income & Rates':
        return Icons.account_balance_rounded;
      case 'Budget & Expenses':
        return Icons.pie_chart_rounded;
      case 'EPF, ETF & Taxes':
        return Icons.verified_user_rounded;
      default:
        return Icons.smart_toy_rounded;
    }
  }

  Color get categoryColor {
    switch (category) {
      case 'CSE & Stocks':
        return AppColors.primary;
      case 'Fixed Income & Rates':
        return AppColors.accentCyan;
      case 'Budget & Expenses':
        return AppColors.gold;
      case 'EPF, ETF & Taxes':
        return AppColors.accentLavender;
      default:
        return AppColors.accentTeal;
    }
  }
}
