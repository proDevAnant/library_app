import '../core/format.dart';

class LibraryInfo {
  final int id;
  final String name;
  final String code;
  final String status;
  final String? planEnd;
  final bool planExpired;

  LibraryInfo({
    required this.id,
    required this.name,
    required this.code,
    required this.status,
    required this.planEnd,
    required this.planExpired,
  });

  factory LibraryInfo.fromJson(Map<String, dynamic> j) => LibraryInfo(
        id: toInt(j['id']),
        name: '${j['name'] ?? ''}',
        code: '${j['code'] ?? ''}',
        status: '${j['status'] ?? ''}',
        planEnd: j['plan_end']?.toString(),
        planExpired: j['plan_expired'] == true,
      );

  int? get planDaysLeft {
    final d = planEnd == null ? null : DateTime.tryParse(planEnd!);
    if (d == null) return null;
    final now = DateTime.now();
    return d.difference(DateTime(now.year, now.month, now.day)).inDays;
  }
}

class AppUser {
  final int id;
  final String name;
  final String phone;
  final String? email;
  final String role; // super_admin | library_admin | student
  final LibraryInfo? library;
  final int? studentId;

  AppUser({
    required this.id,
    required this.name,
    required this.phone,
    required this.email,
    required this.role,
    required this.library,
    required this.studentId,
  });

  factory AppUser.fromJson(Map<String, dynamic> j) => AppUser(
        id: toInt(j['id']),
        name: '${j['name'] ?? ''}',
        phone: '${j['phone'] ?? ''}',
        email: j['email']?.toString(),
        role: '${j['role'] ?? ''}',
        library: j['library'] is Map ? LibraryInfo.fromJson((j['library'] as Map).cast<String, dynamic>()) : null,
        studentId: j['student_id'] == null ? null : toInt(j['student_id']),
      );

  bool get isSuperAdmin => role == 'super_admin';
  bool get isLibraryAdmin => role == 'library_admin';
  bool get isStudent => role == 'student';

  String get roleLabel => switch (role) {
        'super_admin' => 'Super Admin',
        'library_admin' => 'Library Admin',
        _ => 'Student',
      };
}
