import 'category.dart';

enum AccountMode { undecided, individual, company }

class UserProfile {
  const UserProfile({
    required this.uid,
    required this.name,
    required this.cpfMasked,
    required this.email,
    required this.phone,
    required this.jobTitle,
    required this.plate,
    required this.mode,
    required this.settings,
    required this.onboardingDone,
  });

  final String uid;
  final String name;
  final String cpfMasked;
  final String email;
  final String phone;
  final String jobTitle;
  final String plate;
  final AccountMode mode;
  final IndividualSettings settings;

  /// Já passou pela tela de categorias (ou pulou).
  final bool onboardingDone;

  String get firstName => name.trim().split(RegExp(r'\s+')).first;

  String get initials {
    final p = name.trim().split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();
    if (p.isEmpty) return '?';
    if (p.length == 1) return p.first[0].toUpperCase();
    return (p.first[0] + p.last[0]).toUpperCase();
  }

  factory UserProfile.fromMap(String uid, Map<String, dynamic> m) => UserProfile(
        uid: uid,
        name: m['name'] as String? ?? '',
        cpfMasked: m['cpfMasked'] as String? ?? '',
        email: m['email'] as String? ?? '',
        phone: m['phone'] as String? ?? '',
        jobTitle: m['jobTitle'] as String? ?? '',
        plate: m['plate'] as String? ?? '',
        mode: AccountMode.values.firstWhere((x) => x.name == m['mode'], orElse: () => AccountMode.undecided),
        settings: IndividualSettings.fromMap((m['settings'] as Map?)?.cast<String, dynamic>()),
        onboardingDone: m['onboardingDone'] == true,
      );
}
