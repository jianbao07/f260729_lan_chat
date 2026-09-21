class AppErrorCode {
  AppErrorCode._();

  static const connectFailed = 'connectFailed';
  static const cipherNotReady = 'cipherNotReady';
  static const sendFailed = 'sendFailed';
  static const negotiateSendFailed = 'negotiateSendFailed';
  static const peerTempKeyInvalid = 'peerTempKeyInvalid';
  static const peerIdentityInvalid = 'peerIdentityInvalid';
  static const peerTempKeyVerifyFailed = 'peerTempKeyVerifyFailed';
  static const peerIdentityMismatch = 'peerIdentityMismatch';
  static const confirmCipherEmpty = 'confirmCipherEmpty';
  static const confirmMismatch = 'confirmMismatch';
  static const confirmDecryptFailed = 'confirmDecryptFailed';
  static const negotiateException = 'negotiateException';
}
