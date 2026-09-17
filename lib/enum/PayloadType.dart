

enum PayloadType{
  jsonString(11),
  jsonStringCipher(12);

  final int code;
  const PayloadType(this.code);

  static PayloadType? fromCode(int code) {
    for (final type in PayloadType.values) {
      if (type.code == code) return type;
    }
    return null;
  }
}