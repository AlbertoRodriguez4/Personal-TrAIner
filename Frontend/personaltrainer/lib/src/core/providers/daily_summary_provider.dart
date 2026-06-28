import 'package:flutter/material.dart';

import '../../features/home/models/daily_summary.dart';
import '../../services/api_service.dart';

class DailySummaryProvider extends ChangeNotifier {
  DailySummary? _summary;
  bool _isLoading = false;
  String? _error;

  DailySummary? get summary => _summary;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> load() async {
    final uid = ApiService.getCurrentUserId();
    if (uid == null) {
      _error = 'Sesión no iniciada';
      notifyListeners();
      return;
    }
    _setLoading(true);
    _error = null;
    try {
      final raw = await ApiService.getDailySummary(uid);
      _summary = DailySummary.fromJson(raw);
    } catch (e) {
      _error = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void _setLoading(bool v) {
    _isLoading = v;
    notifyListeners();
  }
}