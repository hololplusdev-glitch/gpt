/// Customer reference cached locally for sale association.
class Customer {
  final String id;
  final String name;
  final String? nameAr;
  final String? phone;
  final String? email;
  final String? taxNumber;
  final bool isActive;

  const Customer({
    required this.id,
    required this.name,
    this.nameAr,
    this.phone,
    this.email,
    this.taxNumber,
    this.isActive = true,
  });

  String displayName({bool preferArabic = false}) {
    if (preferArabic && nameAr != null && nameAr!.isNotEmpty) return nameAr!;
    return name;
  }
}
