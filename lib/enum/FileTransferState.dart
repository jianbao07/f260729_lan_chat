enum FileTransferState {
  send("send"),
  rejected("rejected"),
  transferring("transferring"),
  success("success"),
  failed("failed");
  const FileTransferState(this.code);
  final String code;

  static FileTransferState? fromCode(String code) {
    for (final type in FileTransferState.values) {
      if (type.code == code) return type;
    }
    return null;
  }
}
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           