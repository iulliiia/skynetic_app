enum UserRole {
  patient,
  doctor,
  admin;

  static UserRole parse(String v) =>
      UserRole.values.firstWhere((r) => r.name == v, orElse: () => UserRole.patient);
}

enum DoctorVerificationStatus {
  pending,
  approved,
  rejected,
  suspended;

  static DoctorVerificationStatus parse(String? v) => DoctorVerificationStatus.values
      .firstWhere((s) => s.name == v, orElse: () => DoctorVerificationStatus.pending);
}

/// The signed-in account, as returned by `GET /users/me`.
class AuthUser {
  final String id;
  final String email;
  final UserRole role;
  final String status;
  final String? firstName;
  final String? lastName;
  final DoctorVerificationStatus? doctorStatus;

  const AuthUser({
    required this.id,
    required this.email,
    required this.role,
    required this.status,
    this.firstName,
    this.lastName,
    this.doctorStatus,
  });

  String get displayName {
    final full = [firstName, lastName].whereType<String>().join(' ').trim();
    return full.isEmpty ? email : full;
  }

  bool get isApprovedDoctor =>
      role == UserRole.doctor && doctorStatus == DoctorVerificationStatus.approved;

  /// Parses the `/users/me` payload (`user` + optional `patient`/`doctor`).
  factory AuthUser.fromMe(Map<String, dynamic> json) {
    final user = json['user'] as Map<String, dynamic>;
    final patient = json['patient'] as Map<String, dynamic>?;
    final doctor = json['doctor'] as Map<String, dynamic>?;
    final profile = patient ?? doctor;
    return AuthUser(
      id: user['id'] as String,
      email: user['email'] as String,
      role: UserRole.parse(user['role'] as String),
      status: user['status'] as String,
      firstName: profile?['first_name'] as String?,
      lastName: profile?['last_name'] as String?,
      doctorStatus: doctor == null
          ? null
          : DoctorVerificationStatus.parse(doctor['verification_status'] as String?),
    );
  }

  /// Parses the `user` object of a register/login response (no profile yet).
  factory AuthUser.fromSession(Map<String, dynamic> user) => AuthUser(
        id: user['id'] as String,
        email: user['email'] as String,
        role: UserRole.parse(user['role'] as String),
        status: user['status'] as String,
      );
}

/// Patient sign-up fields.
class PatientRegistration {
  final String firstName;
  final String lastName;
  const PatientRegistration({required this.firstName, required this.lastName});

  Map<String, dynamic> toJson() => {'first_name': firstName, 'last_name': lastName};
}

/// Doctor sign-up fields. The account starts as pending verification.
class DoctorRegistration {
  final String firstName;
  final String lastName;
  final String specialty;
  final String registrationNumber;
  final String? institution;
  final String? professionalEmail;

  const DoctorRegistration({
    required this.firstName,
    required this.lastName,
    required this.specialty,
    required this.registrationNumber,
    this.institution,
    this.professionalEmail,
  });

  Map<String, dynamic> toJson() => {
        'first_name': firstName,
        'last_name': lastName,
        'specialty': specialty,
        'registration_number': registrationNumber,
        if (institution != null && institution!.isNotEmpty) 'institution': institution,
        if (professionalEmail != null && professionalEmail!.isNotEmpty)
          'professional_email': professionalEmail,
      };
}
