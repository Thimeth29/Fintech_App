// lib/models/community_models.dart
//
// Community & group records. The app only records and coordinates group
// money: it never holds, collects or transfers it (see
// supabase/migrations/20261013090000_community_groups.sql).

const String kRecordKeepingNotice =
    'Mobile SAP keeps records only. Money is exchanged directly between members.';

const Map<String, String> kInterestLabels = {
  'seettu': 'Seettu',
  'cse': 'CSE stocks',
  'fd': 'Fixed deposits',
  'gold': 'Gold',
  'gov_securities': 'Government securities',
  'business': 'Business / other',
};

const Map<String, String> kExperienceLabels = {
  'none': 'New to investing',
  'some': 'Some experience',
  'experienced': 'Experienced',
};

/// Must match cg_contribution_bucket() in the migration.
const List<String> kContributionBuckets = [
  'Under Rs 10k',
  'Rs 10k–50k',
  'Rs 50k–100k',
  'Rs 100k–250k',
  'Rs 250k–500k',
  'Rs 500k+',
];

/// Index into [kContributionBuckets]; mirrors cg_contribution_bucket().
int? contributionBucket(double? amount) {
  if (amount == null) return null;
  if (amount < 10000) return 0;
  if (amount < 50000) return 1;
  if (amount < 100000) return 2;
  if (amount < 250000) return 3;
  if (amount < 500000) return 4;
  return 5;
}

const List<String> kSriLankaDistricts = [
  'Ampara', 'Anuradhapura', 'Badulla', 'Batticaloa', 'Colombo', 'Galle', 'Gampaha',
  'Hambantota', 'Jaffna', 'Kalutara', 'Kandy', 'Kegalle', 'Kilinochchi', 'Kurunegala',
  'Mannar', 'Matale', 'Matara', 'Monaragala', 'Mullaitivu', 'Nuwara Eliya',
  'Polonnaruwa', 'Puttalam', 'Ratnapura', 'Trincomalee', 'Vavuniya',
];

const Map<String, String> kRoleLabels = {
  'leader': 'Leader',
  'co_leader': 'Co-leader',
  'treasurer': 'Treasurer',
  'member': 'Member',
};

const Map<String, String> kGroupWarningText = {
  'leader_new_account': 'Leader\'s account is less than 7 days old',
  'leader_phone_unverified': 'Leader\'s phone number is not verified',
  'leader_no_completed_groups': 'Leader hasn\'t completed a group yet',
};

double? _toDouble(Object? v) => v == null ? null : (v as num).toDouble();
DateTime? _toDate(Object? v) => v == null ? null : DateTime.tryParse(v.toString())?.toLocal();
List<String> _toStrings(Object? v) => v is List ? v.map((e) => e.toString()).toList() : const [];

class TrustIndicators {
  final bool phoneVerified;
  final DateTime? memberSince;
  final int groupsCompleted;
  final int? seettuOnTimePct;

  const TrustIndicators({
    required this.phoneVerified,
    required this.memberSince,
    required this.groupsCompleted,
    required this.seettuOnTimePct,
  });

  factory TrustIndicators.fromJson(Map<String, dynamic>? j) => TrustIndicators(
        phoneVerified: j?['phone_verified'] == true,
        memberSince: _toDate(j?['member_since']),
        groupsCompleted: (j?['groups_completed'] as num?)?.toInt() ?? 0,
        seettuOnTimePct: (j?['seettu_on_time_pct'] as num?)?.round(),
      );
}

/// The signed-in user's own community profile (from community_my_profile).
class MyCommunityProfile {
  final bool exists;
  final bool availableForGroups;
  final String displayName;
  final String? phone;
  final bool phoneVisibleInSearch;
  final bool phoneVerified;
  final double? maxContribution;
  final String? contributionLabel;
  final String experience;
  final List<String> interests;
  final String? district;
  final String? bio;
  final bool explainerSeen;
  final bool isUnder18;
  final bool canBeAvailable;
  final bool requirePhoneVerification;
  final String defaultDisplayName;
  final String? defaultPhone;
  final TrustIndicators trust;

  const MyCommunityProfile({
    required this.exists,
    required this.availableForGroups,
    required this.displayName,
    required this.phone,
    required this.phoneVisibleInSearch,
    required this.phoneVerified,
    required this.maxContribution,
    required this.contributionLabel,
    required this.experience,
    required this.interests,
    required this.district,
    required this.bio,
    required this.explainerSeen,
    required this.isUnder18,
    required this.canBeAvailable,
    required this.requirePhoneVerification,
    required this.defaultDisplayName,
    required this.defaultPhone,
    required this.trust,
  });

  factory MyCommunityProfile.fromJson(Map<String, dynamic> j) {
    final p = j['profile'] is Map ? Map<String, dynamic>.from(j['profile'] as Map) : const <String, dynamic>{};
    return MyCommunityProfile(
      exists: j['exists'] == true,
      availableForGroups: p['available_for_groups'] == true,
      displayName: (p['display_name'] as String?) ?? '',
      phone: p['phone'] as String?,
      phoneVisibleInSearch: p['phone_visible_in_search'] == true,
      phoneVerified: p['phone_verified'] == true,
      maxContribution: _toDouble(p['max_contribution']),
      contributionLabel: j['contribution_label'] as String?,
      experience: (p['experience'] as String?) ?? 'none',
      interests: _toStrings(p['interests']),
      district: p['district'] as String?,
      bio: p['bio'] as String?,
      explainerSeen: p['explainer_seen_at'] != null,
      isUnder18: j['is_under_18'] == true,
      canBeAvailable: j['can_be_available'] == true,
      requirePhoneVerification: j['require_phone_verification'] == true,
      defaultDisplayName: (j['default_display_name'] as String?) ?? '',
      defaultPhone: j['default_phone'] as String?,
      trust: TrustIndicators.fromJson(j['trust'] is Map ? Map<String, dynamic>.from(j['trust'] as Map) : null),
    );
  }
}

/// A person as others see them (search results and profile views).
class PersonResult {
  final String userId;
  final String displayName;
  final String? photoPath;
  final String? contributionLabel;
  final String experience;
  final List<String> interests;
  final String? district;
  final String? bio;
  final bool phoneVerified;
  final String? phone;
  final DateTime? memberSince;
  final String? connectionStatus;

  const PersonResult({
    required this.userId,
    required this.displayName,
    this.photoPath,
    this.contributionLabel,
    this.experience = 'none',
    this.interests = const [],
    this.district,
    this.bio,
    this.phoneVerified = false,
    this.phone,
    this.memberSince,
    this.connectionStatus,
  });

  factory PersonResult.fromJson(Map<String, dynamic> j) => PersonResult(
        userId: j['user_id'] as String,
        displayName: (j['display_name'] as String?) ?? 'Member',
        photoPath: j['photo_path'] as String?,
        contributionLabel: j['contribution_label'] as String?,
        experience: (j['experience'] as String?) ?? 'none',
        interests: _toStrings(j['interests']),
        district: j['district'] as String?,
        bio: j['bio'] as String?,
        phoneVerified: j['phone_verified'] == true,
        phone: j['phone'] as String?,
        memberSince: _toDate(j['member_since']),
        connectionStatus: j['connection_status'] as String?,
      );
}

class GroupResult {
  final String id;
  final String type; // seettu | investment
  final String name;
  final String? description;
  final String? district;
  final int memberCount;
  final int maxMembers;
  final double? contribution; // seettu
  final double? minContribution; // investment
  final double? maxContribution; // investment
  final String? frequency;
  final String? leaderName;
  final String? leaderExperience;
  final String status;
  final bool isOpen;
  final bool isMember;
  final String? myRequestStatus;
  final List<String> warnings;

  const GroupResult({
    required this.id,
    required this.type,
    required this.name,
    this.description,
    this.district,
    required this.memberCount,
    required this.maxMembers,
    this.contribution,
    this.minContribution,
    this.maxContribution,
    this.frequency,
    this.leaderName,
    this.leaderExperience,
    required this.status,
    required this.isOpen,
    required this.isMember,
    this.myRequestStatus,
    this.warnings = const [],
  });

  bool get isSeettu => type == 'seettu';

  factory GroupResult.fromJson(Map<String, dynamic> j) => GroupResult(
        id: j['group_id'] as String,
        type: j['type'] as String,
        name: j['name'] as String,
        description: j['description'] as String?,
        district: j['district'] as String?,
        memberCount: (j['member_count'] as num?)?.toInt() ?? 0,
        maxMembers: (j['max_members'] as num?)?.toInt() ?? 0,
        contribution: _toDouble(j['contribution']),
        minContribution: _toDouble(j['min_contribution']),
        maxContribution: _toDouble(j['max_contribution']),
        frequency: j['frequency'] as String?,
        leaderName: j['leader_name'] as String?,
        leaderExperience: j['leader_experience'] as String?,
        status: (j['status'] as String?) ?? 'forming',
        isOpen: j['is_open'] == true,
        isMember: j['is_member'] == true,
        myRequestStatus: j['my_request_status'] as String?,
        warnings: _toStrings(j['warnings']),
      );
}

/// Full summary a non-member may see before joining (community_group_summary).
class GroupSummary {
  final Map<String, dynamic> raw;
  const GroupSummary(this.raw);

  String get id => raw['id'] as String;
  String get type => raw['type'] as String;
  bool get isSeettu => type == 'seettu';
  String get name => raw['name'] as String;
  String? get description => raw['description'] as String?;
  String get rules => (raw['rules'] as String?) ?? '';
  String get status => (raw['status'] as String?) ?? 'forming';
  int get memberCount => (raw['member_count'] as num?)?.toInt() ?? 0;
  int get maxMembers => (raw['max_members'] as num?)?.toInt() ?? 0;
  String get joinApproval => (raw['join_approval'] as String?) ?? 'leader';
  String get votingMethod => (raw['voting_method'] as String?) ?? 'one_member_one_vote';
  bool get isMember => raw['is_member'] == true;
  String? get leaderName => (raw['leader'] as Map?)?['display_name'] as String?;
  List<String> get warnings => _toStrings(raw['warnings']);
  Map<String, dynamic>? get seettu => raw['seettu'] is Map ? Map<String, dynamic>.from(raw['seettu'] as Map) : null;
  Map<String, dynamic>? get investment =>
      raw['investment'] is Map ? Map<String, dynamic>.from(raw['investment'] as Map) : null;
  String? get myRequestStatus => (raw['my_request'] as Map?)?['status'] as String?;
  String? get myInviteId => (raw['my_invite'] as Map?)?['id'] as String?;
}

class ConnectionEntry {
  final String connectionId;
  final String userId;
  final String displayName;
  final String? phone;
  final bool phoneVerified;
  final String? experience;
  final String? district;
  final String status; // pending | accepted
  final String direction; // incoming | outgoing
  final String? message;
  final DateTime? createdAt;

  const ConnectionEntry({
    required this.connectionId,
    required this.userId,
    required this.displayName,
    this.phone,
    this.phoneVerified = false,
    this.experience,
    this.district,
    required this.status,
    required this.direction,
    this.message,
    this.createdAt,
  });

  bool get isAccepted => status == 'accepted';
  bool get isIncoming => direction == 'incoming';

  factory ConnectionEntry.fromJson(Map<String, dynamic> j) => ConnectionEntry(
        connectionId: j['connection_id'] as String,
        userId: j['user_id'] as String,
        displayName: (j['display_name'] as String?) ?? 'Member',
        phone: j['phone'] as String?,
        phoneVerified: j['phone_verified'] == true,
        experience: j['experience'] as String?,
        district: j['district'] as String?,
        status: j['status'] as String,
        direction: j['direction'] as String,
        message: j['message'] as String?,
        createdAt: _toDate(j['created_at']),
      );
}

class BlockedUser {
  final String userId;
  final String displayName;
  const BlockedUser(this.userId, this.displayName);
}

/// A group I'm an active member of.
class MyGroup {
  final String id;
  final String name;
  final String type;
  final String status;
  final String role;
  final int maxMembers;
  final int unread;

  const MyGroup({
    required this.id,
    required this.name,
    required this.type,
    required this.status,
    required this.role,
    required this.maxMembers,
    this.unread = 0,
  });

  bool get isSeettu => type == 'seettu';

  MyGroup withUnread(int n) =>
      MyGroup(id: id, name: name, type: type, status: status, role: role, maxMembers: maxMembers, unread: n);
}

class GroupInvite {
  final String id;
  final String groupId;
  final DateTime? createdAt;
  final GroupSummary? summary;
  const GroupInvite({required this.id, required this.groupId, this.createdAt, this.summary});
}

class GroupMember {
  final String userId;
  final String displayName;
  final String role;
  final DateTime? joinedAt;
  const GroupMember({required this.userId, required this.displayName, required this.role, this.joinedAt});
}

class AppNotification {
  final String id;
  final String kind;
  final String title;
  final String? body;
  final String? groupId;
  final Map<String, dynamic> data;
  final DateTime? readAt;
  final DateTime createdAt;

  const AppNotification({
    required this.id,
    required this.kind,
    required this.title,
    this.body,
    this.groupId,
    this.data = const {},
    this.readAt,
    required this.createdAt,
  });

  bool get isRead => readAt != null;

  factory AppNotification.fromJson(Map<String, dynamic> j) => AppNotification(
        id: j['id'] as String,
        kind: j['kind'] as String,
        title: j['title'] as String,
        body: j['body'] as String?,
        groupId: j['group_id'] as String?,
        data: j['data'] is Map ? Map<String, dynamic>.from(j['data'] as Map) : const {},
        readAt: _toDate(j['read_at']),
        createdAt: _toDate(j['created_at']) ?? DateTime.now(),
      );
}
