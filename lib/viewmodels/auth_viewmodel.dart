import 'package:flutter/foundation.dart';
import '../services/auth_service.dart';

class AuthViewModel extends ChangeNotifier {
  final AuthService _authService = AuthService();

  bool isLoading = false;
  String? errorMessage;
  String displayName = '';

  bool get isLoggedIn => _authService.currentUser != null;

  Future<bool> signUp({
    required String name,
    required String email,
    required String password,
    required String mobile,
  }) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      await _authService.signUp(
        name: name,
        email: email,
        password: password,
        mobile: mobile,
      );
      displayName = name;
      return true;
    } catch (e) {
      errorMessage = 'Sign up failed: ${e.toString()}';
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> signIn({required String email, required String password}) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      await _authService.signIn(email: email, password: password);
      displayName = await _authService.fetchDisplayName();
      return true;
    } catch (e) {
      errorMessage = 'Login failed: ${e.toString()}';
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadDisplayName() async {
    displayName = await _authService.fetchDisplayName();
    notifyListeners();
  }

  Future<void> signOut() async {
    await _authService.signOut();
    displayName = '';
    notifyListeners();
  }
}
