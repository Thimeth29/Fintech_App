import 'package:flutter/foundation.dart';
import '../services/auth_service.dart';

class AuthViewModel extends ChangeNotifier {
  final AuthService _authService = AuthService();

  bool isLoading = false;
  String? errorMessage;
  String displayName = '';
  Map<String, dynamic>? userProfile;

  bool get isLoggedIn => _authService.currentUser != null;

  Future<bool> signUp({
    required String name,
    required String email,
    required String password,
    String? phone,
    Map<String, dynamic>? extraMetaData,
  }) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      await _authService.signUp(
        name: name,
        email: email,
        password: password,
        phone: phone,
        extraMetaData: extraMetaData,
      );
      displayName = name;
      await loadUserProfile();
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
      await loadUserProfile();
      return true;
    } catch (e) {
      errorMessage = 'Login failed: ${e.toString()}';
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadUserProfile() async {
    userProfile = await _authService.fetchProfile();
    displayName = await _authService.fetchDisplayName();
    notifyListeners();
  }

  Future<void> updateProfile(Map<String, dynamic> updates) async {
    isLoading = true;
    notifyListeners();
    try {
      await _authService.updateProfile(updates);
      await loadUserProfile();
    } catch (e) {
      errorMessage = 'Update profile failed: ${e.toString()}';
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
    userProfile = null;
    notifyListeners();
  }
}
