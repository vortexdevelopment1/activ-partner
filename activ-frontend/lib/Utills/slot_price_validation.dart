String? validateSlotCapacity(String? value) {
  final capacity = int.tryParse((value ?? '').trim());
  return capacity == null || capacity <= 0 || capacity > 2147483647
      ? 'Enter a valid whole number of members greater than 0.'
      : null;
}

String? validateSlotPrice(String? value) {
  final price = double.tryParse((value ?? '').trim());
  return price == null || !price.isFinite || price <= 0
      ? 'Enter a valid slot price greater than 0.'
      : null;
}

String? validateDiscountedSlotPrice(String? value, String? basePrice) {
  final text = (value ?? '').trim();
  if (text.isEmpty) return null;
  final discounted = double.tryParse(text);
  if (discounted == null || !discounted.isFinite || discounted < 0) {
    return 'Enter a valid discounted price of 0 or more.';
  }
  final price = double.tryParse((basePrice ?? '').trim());
  return price != null && price.isFinite && discounted > price
      ? 'Discounted price cannot exceed the slot price.'
      : null;
}
