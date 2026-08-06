
enum MessageStateType{
  sending("sending"),fail("fail"),success("success"),
  transfer("transfer");//传输状态，文件传输特有

  const MessageStateType(this.code);

  final String code;

  static MessageStateType? fromCode(String code) {
    for (final type in MessageStateType.values) {
      if (type.code == code) return type;
    }
    return null;
  }
}