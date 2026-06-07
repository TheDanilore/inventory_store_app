class PeruData {
  static const List<String> departments = [
    'Ancash',
    'Lima',
  ];

  static const Map<String, List<String>> provincesByDepartment = {
    'Ancash': ['Santa', 'Huaraz', 'Casma'],
    'Lima': ['Lima', 'Huaral'],
  };

  static const Map<String, List<String>> districtsByProvince = {
    'Santa': ['Chimbote', 'Nuevo Chimbote', 'Santa'],
    'Huaraz': ['Huaraz', 'Independencia'],
    'Casma': ['Casma', 'Buena Vista Alta'],
    'Lima': ['Lima', 'Miraflores', 'Santiago de Surco'],
    'Huaral': ['Huaral', 'Aucallama'],
  };

  static const Set<String> coveredDistricts = {
    'Chimbote',
    'Nuevo Chimbote',
    'Santa',
  };

  static List<String> provincesOf(String? department) {
    if (department == null) return const [];
    return provincesByDepartment[department] ?? const [];
  }

  static List<String> districtsOf(String? province) {
    if (province == null) return const [];
    return districtsByProvince[province] ?? const [];
  }

  static bool isCoveredDistrict(String? district) {
    if (district == null) return false;
    return coveredDistricts.contains(district);
  }
}