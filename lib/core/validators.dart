/// Same rules as the PHP backend, so mistakes are caught before sending.
class V {
  static String digits(String s) {
    var d = s.replaceAll(RegExp(r'\D'), '');
    if (d.length == 12 && d.startsWith('91')) d = d.substring(2);
    if (d.length == 11 && d.startsWith('0')) d = d.substring(1);
    return d;
  }

  static String? phone(String? v) {
    if (v == null || v.trim().isEmpty) return 'Enter mobile number';
    return RegExp(r'^[6-9]\d{9}$').hasMatch(digits(v)) ? null : 'Enter a valid 10-digit mobile number';
  }

  static String? optionalPhone(String? v) => (v == null || v.trim().isEmpty) ? null : phone(v);

  static String? required(String? v, [String what = 'This field']) =>
      (v == null || v.trim().isEmpty) ? '$what is required' : null;

  static String? password(String? v) {
    if (v == null || v.isEmpty) return 'Enter a password';
    if (v.length < 8) return 'At least 8 characters';
    if (!RegExp(r'[A-Za-z]').hasMatch(v) || !RegExp(r'\d').hasMatch(v)) return 'Use letters and numbers';
    return null;
  }

  static String? email(String? v) {
    if (v == null || v.trim().isEmpty) return null;
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v.trim()) ? null : 'Enter a valid email';
  }

  static String? amount(String? v, {bool allowZero = false}) {
    if (v == null || v.trim().isEmpty) return 'Enter amount';
    final n = num.tryParse(v.trim());
    if (n == null || !RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(v.trim())) return 'Enter an amount like 500';
    if (!allowZero && n <= 0) return 'Amount must be more than 0';
    return null;
  }
}
