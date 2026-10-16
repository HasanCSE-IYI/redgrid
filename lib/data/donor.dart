import '../core/constants.dart';

class Donor {
  const Donor({
    this.id,
    required this.name,
    required this.bloodGroup,
    required this.gender,
    required this.phone,
    required this.consentToShare,
    required this.district,
    required this.area,
    this.lastDonationDate,
    this.totalDonations = 0,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  final int? id;
  final String name;
  final String bloodGroup;
  final String gender;
  final String phone;
  final bool consentToShare;
  final String district;
  final String area;
  final String? lastDonationDate;
  final int totalDonations;
  final String? notes;
  final String createdAt;
  final String updatedAt;

  bool get isFemale => gender == AppConstants.genderFemale;

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        'blood_group': bloodGroup,
        'gender': gender,
        'phone': phone,
        'consent_to_share': consentToShare ? 1 : 0,
        'district': district,
        'area': area,
        'last_donation_date': lastDonationDate,
        'total_donations': totalDonations,
        'notes': notes,
        'created_at': createdAt,
        'updated_at': updatedAt,
      };

  factory Donor.fromMap(Map<String, Object?> map) => Donor(
        id: map['id'] as int?,
        name: map['name'] as String,
        bloodGroup: map['blood_group'] as String,
        gender: map['gender'] as String,
        phone: map['phone'] as String,
        consentToShare: (map['consent_to_share'] as int) == 1,
        district: map['district'] as String,
        area: map['area'] as String,
        lastDonationDate: map['last_donation_date'] as String?,
        totalDonations: map['total_donations'] as int,
        notes: map['notes'] as String?,
        createdAt: map['created_at'] as String,
        updatedAt: map['updated_at'] as String,
      );
}
