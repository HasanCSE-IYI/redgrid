const String _banglaDigits = '০১২৩৪৫৬৭৮৯';
const String _asciiDigits = '0123456789';

/// বাংলা অঙ্ক (০-৯) কে ইংরেজি অঙ্কে (0-9) বদলায়।
String toAsciiDigits(String input) {
  final buffer = StringBuffer();
  for (final rune in input.runes) {
    final char = String.fromCharCode(rune);
    final index = _banglaDigits.indexOf(char);
    buffer.write(index >= 0 ? _asciiDigits[index] : char);
  }
  return buffer.toString();
}

/// ইংরেজি অঙ্ককে বাংলা অঙ্কে বদলায় (শুধু দেখানোর জন্য)।
String toBanglaDigits(Object value) {
  final buffer = StringBuffer();
  for (final rune in value.toString().runes) {
    final char = String.fromCharCode(rune);
    final index = _asciiDigits.indexOf(char);
    buffer.write(index >= 0 ? _banglaDigits[index] : char);
  }
  return buffer.toString();
}
