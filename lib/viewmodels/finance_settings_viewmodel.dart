import 'package:flutter/foundation.dart';
import '../models/finance_settings_model.dart';
import '../services/finance_data_services.dart';

class FinanceSettingsViewModel extends ChangeNotifier {
  final FinanceSettingsService _service = FinanceSettingsService();

  String? _userId;
  bool isLoading = false;
  String? errorMessage;
  FinanceSettings settings = const FinanceSettings();

  bool get isLoggedIn => (_userId ?? '').isNotEmpty;

  @visibleForTesting
  void seedForTest({required String userId, FinanceSettings settings = const FinanceSettings()}) {
    _userId = userId;
    this.settings = settings;
    notifyListeners();
  }

  Future<void> load(String userId) async {
    _userId = userId;
    if (userId.isEmpty) return;
    isLoading = true;
    notifyListeners();
    try {
      settings = await _service.fetch(userId) ?? const FinanceSettings();
      errorMessage = null;
    } catch (_) {
      errorMessage = 'Could not load income settings.';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> save({double? monthlyIncome, int? incomeDay}) async {
    if (!isLoggedIn) return false;
    try {
      settings = await _service.save(_userId!, monthlyIncome: monthlyIncome, incomeDay: incomeDay) ??
          settings;
      errorMessage = null;
      notifyListeners();
      return true;
    } catch (_) {
      errorMessage = 'Could not save income settings.';
      notifyListeners();
      return false;
    }
  }
}
