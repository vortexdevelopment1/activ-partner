/// Validates the PAN-based GSTIN structure and its base-36 check character.
bool isValidGstin(String value) {
  final gstin = value.trim().toUpperCase();
  if (!RegExp(
          r'^(0[1-9]|[12][0-9]|3[0-8]|97|99)[A-Z]{5}[0-9]{4}[A-Z][1-9A-Z]Z[0-9A-Z]$')
      .hasMatch(gstin)) {
    return false;
  }
  const alphabet = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ';
  var sum = 0;
  for (var index = 0; index < 14; index++) {
    final product = alphabet.indexOf(gstin[index]) * (index.isEven ? 1 : 2);
    sum += product ~/ 36 + product % 36;
  }
  return gstin[14] == alphabet[(36 - sum % 36) % 36];
}
