
enum MessageType{
  text("text"),rawAck("ack"),file("file"),tempPublicKey("tempPublicKey"),ciphertextOk("ciphertextOk");

  const MessageType(this.code);

  final String code;

  static MessageType? fromCode(String code) {
    for (final type in MessageType.values) {
      if (type.code == code) return type;
    }
    return null;
  }
}