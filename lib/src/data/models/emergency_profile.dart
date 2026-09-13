/// Medical/contact details a user can optionally save so they travel with
/// any Ping for Help alert — stored locally on the device only, never sent
/// anywhere on its own.
class EmergencyProfile {
  const EmergencyProfile({
    this.fullName = '',
    this.bloodGroup = '',
    this.conditions = '',
    this.allergies = '',
    this.nextOfKin = '',
    this.nextOfKinPhone = '',
  });

  static const empty = EmergencyProfile();

  final String fullName;
  final String bloodGroup;
  final String conditions;
  final String allergies;
  final String nextOfKin;
  final String nextOfKinPhone;

  bool get isEmpty =>
      fullName.isEmpty &&
      bloodGroup.isEmpty &&
      conditions.isEmpty &&
      allergies.isEmpty &&
      nextOfKin.isEmpty &&
      nextOfKinPhone.isEmpty;
}
