import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

String normalizeCustomFieldDecimal(String raw, Locale locale) {
  final decimalSeparator = NumberFormat.decimalPattern(
    locale.toString(),
  ).symbols.DECIMAL_SEP;
  return decimalSeparator == '.' ? raw : raw.replaceAll(decimalSeparator, '.');
}
