// lib/viewmodels/community_viewmodel.dart
//
// State for the Community hub. Local state only changes after the server
// accepts a write: actions await their RPC, then reload what changed.
// Actions return null on success or a friendly error message.

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show RealtimeChannel;

import '../models/community_models.dart';
import '../services/community_service.dart';

class CommunityViewModel extends ChangeNotifier {
  final CommunityService service;
  CommunityViewModel({CommunityService? service}) : service = service ?? CommunityService();

  /// The first-open explainer shows once per app session even before the
  /// user has a profile to record it on.
  static bool explainerShownThisSession = false;

  bool isLoading = true;
  String? errorCode;
  MyCommunityProfile? profile;
  List<ConnectionEntry> connections = const [];
  List<BlockedUser> blocked = const [];
  List<MyGroup> myGroups = const [];
  List<GroupInvite> invites = const [];
  List<AppNotification> notifications = const [];
  int unreadNotifications = 0;
  int incomingRequests = 0;

  RealtimeChannel? _channel;
  bool _disposed = false;

  bool get unavailable => errorCode == 'community_unavailable';
  bool get notLoggedIn => errorCode == 'not_authenticated';
  bool get hasProfile => profile?.exists ?? false;
  bool get isAvailable => profile?.availableForGroups ?? false;
  bool get shouldShowExplainer =>
      !explainerShownThisSession && profile != null && !(profile!.exists && profile!.explainerSeen);

  List<ConnectionEntry> get friends => connections.where((c) => c.isAccepted).toList();
  List<ConnectionEntry> get received => connections.where((c) => !c.isAccepted && c.isIncoming).toList();
  List<ConnectionEntry> get sent => connections.where((c) => !c.isAccepted && !c.isIncoming).toList();

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<String?> _run(Future<void> Function() action) async {
    try {
      await action();
      return null;
    } on CommunityException catch (e) {
      return e.message;
    } catch (_) {
      return communityErrorText('network');
    }
  }

  Future<void> load() async {
    isLoading = true;
    errorCode = null;
    _notify();
    try {
      profile = await service.myProfile();
      await Future.wait([
        refreshConnections(),
        refreshGroups(),
        refreshUnread(),
      ]);
      _channel ??= service.watchNotifications(() {
        refreshUnread();
        if (notifications.isNotEmpty) refreshNotifications();
      });
    } on CommunityException catch (e) {
      errorCode = e.code;
    } catch (_) {
      errorCode = 'network';
    }
    isLoading = false;
    _notify();
  }

  Future<void> refreshConnections() async {
    try {
      final results = await Future.wait([service.connections(), service.blocked()]);
      connections = results[0] as List<ConnectionEntry>;
      blocked = results[1] as List<BlockedUser>;
      incomingRequests = received.length;
      _notify();
    } on CommunityException catch (_) {}
  }

  Future<void> refreshGroups() async {
    try {
      final results = await Future.wait([service.myGroups(), service.myInvites(), service.unreadSummary()]);
      final chats = Map<String, dynamic>.from((results[2] as Map)['chats'] as Map? ?? {});
      myGroups = (results[0] as List<MyGroup>)
          .map((g) => g.withUnread((chats[g.id] as num?)?.toInt() ?? 0))
          .toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      invites = results[1] as List<GroupInvite>;
      _notify();
    } on CommunityException catch (_) {}
  }

  Future<void> refreshUnread() async {
    try {
      final s = await service.unreadSummary();
      unreadNotifications = (s['notifications'] as num?)?.toInt() ?? 0;
      incomingRequests = (s['incoming_requests'] as num?)?.toInt() ?? incomingRequests;
      _notify();
    } on CommunityException catch (_) {}
  }

  Future<void> refreshNotifications() async {
    try {
      notifications = await service.notifications();
      unreadNotifications = notifications.where((n) => !n.isRead).length;
      _notify();
    } on CommunityException catch (_) {}
  }

  Future<String?> markAllNotificationsRead() => _run(() async {
        final ids = notifications.where((n) => !n.isRead).map((n) => n.id).toList();
        await service.markNotificationsRead(ids);
        await refreshNotifications();
      });

  Future<String?> markNotificationRead(String id) => _run(() async {
        await service.markNotificationsRead([id]);
        await refreshNotifications();
      });

  // ---------------------------------------------------------------- profile
  Future<void> dismissExplainer() async {
    explainerShownThisSession = true;
    _notify();
    if (hasProfile) {
      try {
        await service.markExplainerSeen();
      } catch (_) {}
    }
  }

  Future<String?> saveProfile({
    required String displayName,
    String? phone,
    required bool phoneVisibleInSearch,
    double? maxContribution,
    required String experience,
    required List<String> interests,
    String? district,
    String? bio,
  }) =>
      _run(() async {
        final firstSave = !hasProfile;
        profile = await service.saveProfile(
          displayName: displayName,
          phone: phone,
          phoneVisibleInSearch: phoneVisibleInSearch,
          maxContribution: maxContribution,
          experience: experience,
          interests: interests,
          district: district,
          bio: bio,
        );
        if (firstSave && explainerShownThisSession) await service.markExplainerSeen();
        _notify();
      });

  Future<String?> confirmAge() => _run(() async {
        profile = await service.confirmAge();
        _notify();
      });

  Future<String?> setAvailable(bool value) => _run(() async {
        profile = await service.setAvailable(value);
        _notify();
      });

  // ---------------------------------------------------------- connections
  Future<String?> requestConnection(String userId, {String? message}) => _run(() async {
        await service.requestConnection(userId, message: message);
        await refreshConnections();
      });

  Future<String?> respond(ConnectionEntry c, bool accept) => _run(() async {
        await service.respondConnection(c.connectionId, accept);
        await refreshConnections();
      });

  Future<String?> cancelRequest(ConnectionEntry c) => _run(() async {
        await service.cancelConnection(c.connectionId);
        await refreshConnections();
      });

  Future<String?> removeConnection(String userId) => _run(() async {
        await service.removeConnection(userId);
        await refreshConnections();
      });

  Future<String?> block(String userId) => _run(() async {
        await service.block(userId);
        await refreshConnections();
      });

  Future<String?> unblock(String userId) => _run(() async {
        await service.unblock(userId);
        await refreshConnections();
      });

  Future<String?> report({
    required String targetType,
    required String reason,
    String? details,
    String? userId,
    String? groupId,
    bool isScam = false,
  }) =>
      _run(() => service.report(
            targetType: targetType,
            reason: reason,
            details: details,
            userId: userId,
            groupId: groupId,
            isScam: isScam,
          ));

  // --------------------------------------------------------------- groups
  Future<String?> requestJoin(String groupId, {String? message}) => _run(() async {
        await service.requestJoin(groupId, message: message);
        await refreshGroups();
      });

  Future<String?> respondInvite(GroupInvite invite, bool accept) => _run(() async {
        await service.respondInvite(invite.id, accept);
        await refreshGroups();
      });

  Future<String?> inviteToGroup(String groupId, String userId) => _run(() => service.invite(groupId, userId));

  Future<String?> leaveGroup(String groupId) => _run(() async {
        await service.leaveGroup(groupId);
        await refreshGroups();
      });

  @override
  void dispose() {
    _disposed = true;
    final channel = _channel;
    if (channel != null) service.removeChannel(channel);
    super.dispose();
  }
}
