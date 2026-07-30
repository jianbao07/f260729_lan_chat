
enum RawMessageType {
  beat("beat");

  const RawMessageType(this.code);

  final String code;

  static RawMessageType? fromCode(String code) {
    for (final type in RawMessageType.values) {
      if (type.code == code) return type;
    }
    return null;
  }
}