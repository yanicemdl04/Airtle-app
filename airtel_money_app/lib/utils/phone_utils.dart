/// Normalise un numéro saisi pour correspondre au format stocké en base (+243…).
String normalizePhone(String raw) {
  var phone = raw.trim().replaceAll(RegExp(r'[\s\-()]'), '');
  if (phone.isEmpty) return phone;

  if (!phone.startsWith('+')) {
    if (phone.startsWith('00')) {
      phone = '+${phone.substring(2)}';
    } else if (phone.startsWith('0') && phone.length >= 10) {
      phone = '+243${phone.substring(1)}';
    } else if (phone.startsWith('243')) {
      phone = '+$phone';
    } else if (RegExp(r'^\d{9,10}$').hasMatch(phone)) {
      phone = '+243$phone';
    } else {
      phone = '+$phone';
    }
  }

  return phone;
}
