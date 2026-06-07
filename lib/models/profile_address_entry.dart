class ProfileAddressEntry {
  final String id;
  final String addressLine;
  final String? reference;
  final String department;
  final String province;
  final String district;
  final bool isDefault;

  const ProfileAddressEntry({
    required this.id,
    required this.addressLine,
    required this.department,
    required this.province,
    required this.district,
    required this.isDefault,
    this.reference,
  });
}
