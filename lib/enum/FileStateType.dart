enum FileStateType {
  send("send"),
  rejected("rejected"),
  transferring("transferring"),
  success("success");
  const FileStateType(this.code);
  final String code;

  static FileStateType? fromCode(String code) {
    for (final type in FileStateType.values) {
      if (type.code == code) return type;
    }
    return null;
  }
}
