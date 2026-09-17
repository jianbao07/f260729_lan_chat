enum CipherSessionState {
  idle("idle"),
  establishing("establishing"),
  ready("ready"),
  failed("failed");

  const CipherSessionState(this.code);
  final String code;

  static CipherSessionState? fromCode(String? code) {
    for (final type in CipherSessionState.values) {
      if (type.code == code) return type;
    }
    return null;
  }
}
