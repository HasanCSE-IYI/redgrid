/// অ্যাপের স্থির মানগুলো এক জায়গায়।
class AppConstants {
  AppConstants._();

  static const bloodGroups = ['A+', 'A-', 'B+', 'B-', 'O+', 'O-', 'AB+', 'AB-', 'Oh'];

  static const genderMale = 'MALE';
  static const genderFemale = 'FEMALE';
  static const genders = [genderMale, genderFemale];

  static const maleCooldownDays = 90;
  static const femaleCooldownDays = 120;

  static const schemaVersion = 1;

  static const maxNameLength = 80;
  static const maxPlaceLength = 60;
  static const maxNotesLength = 300;

  static const tableDonors = 'donors';
  static const tableLogs = 'donation_logs';
}
