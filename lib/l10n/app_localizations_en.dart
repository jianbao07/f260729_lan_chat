// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'LAN Chat';

  @override
  String get appTagline => 'Instant messaging on your LAN';

  @override
  String get tabChats => 'Chats';

  @override
  String get tabDevices => 'Devices';

  @override
  String get tabMe => 'Me';

  @override
  String get lanDevices => 'LAN devices';

  @override
  String get unknownDevice => 'Unknown device';

  @override
  String get unknown => 'Unknown';

  @override
  String get copy => 'Copy';

  @override
  String get copied => 'Copied';

  @override
  String get close => 'Close';

  @override
  String get share => 'Share';

  @override
  String get save => 'Save';

  @override
  String get saveAs => 'Save as';

  @override
  String get showInFolder => 'Show in folder';

  @override
  String get showInFolderFailed => 'Could not open folder';

  @override
  String get saved => 'Saved';

  @override
  String get retry => 'Retry';

  @override
  String get resend => 'Resend';

  @override
  String get online => 'Online';

  @override
  String get offline => 'Offline';

  @override
  String get file => 'File';

  @override
  String get image => 'Image';

  @override
  String get me => 'Me';

  @override
  String get thisDevice => 'This device';

  @override
  String get accept => 'Accept';

  @override
  String get decline => 'Decline';

  @override
  String get justNow => 'Just now';

  @override
  String minutesAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count min ago',
      one: '1 min ago',
    );
    return '$_temp0';
  }

  @override
  String hoursAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count hr ago',
      one: '1 hr ago',
    );
    return '$_temp0';
  }

  @override
  String daysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days ago',
      one: '1 day ago',
    );
    return '$_temp0';
  }

  @override
  String get deviceNotFound => 'Device info not found';

  @override
  String get noConversations => 'No conversations yet';

  @override
  String get noConversationsHint => 'Find a device on the LAN, then say hello';

  @override
  String get noMessages => 'No messages';

  @override
  String scanDone(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Scan complete, found $count devices',
      one: 'Scan complete, found 1 device',
    );
    return '$_temp0';
  }

  @override
  String subnetSuffix(String cidr) {
    return ' · subnet $cidr';
  }

  @override
  String onlineCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count online',
      one: '1 online',
    );
    return '$_temp0';
  }

  @override
  String get noOnlineDevices => 'No devices online';

  @override
  String get noOnlineDevicesHint =>
      'Make sure the other person has the app open and is on the same network';

  @override
  String deviceNameLabel(String name) {
    return 'Device name $name';
  }

  @override
  String get sectionDeviceInfo => 'Device info';

  @override
  String get nickname => 'Nickname';

  @override
  String get tapToSetNickname => 'Tap to set a nickname';

  @override
  String get nicknameCleared => 'Nickname cleared';

  @override
  String get nicknameSaved => 'Nickname saved';

  @override
  String get ipAddress => 'IP address';

  @override
  String get deviceId => 'Device ID';

  @override
  String get publicKey => 'Public key';

  @override
  String get sectionGeneral => 'General';

  @override
  String get theme => 'Theme';

  @override
  String get language => 'Language';

  @override
  String get notifications => 'Notifications';

  @override
  String get discoverable => 'Allow LAN discovery';

  @override
  String get encryptTransfer => 'Encrypted transfer';

  @override
  String get sectionAbout => 'About';

  @override
  String get version => 'Version';

  @override
  String get privacyPolicy => 'Privacy Policy';

  @override
  String get userAgreement => 'User Agreement';

  @override
  String get helpFeedback => 'Help & Feedback';

  @override
  String get themeSystem => 'System';

  @override
  String get themeDark => 'Dark';

  @override
  String get themeLight => 'Light';

  @override
  String get localeSystem => 'System';

  @override
  String get localeZh => '中文';

  @override
  String get localeEn => 'English';

  @override
  String get profileTitle => 'Profile';

  @override
  String originalName(String name) {
    return 'Original name $name';
  }

  @override
  String get remark => 'Alias';

  @override
  String get tapToSetRemark => 'Tap to set an alias';

  @override
  String get remarkCleared => 'Alias cleared';

  @override
  String get remarkSaved => 'Alias saved';

  @override
  String get sendMessage => 'Send message';

  @override
  String offlineLastSeen(String time) {
    return 'Offline · last seen $time';
  }

  @override
  String get peerAddressInvalid => 'Peer address is invalid';

  @override
  String get deviceNotReady => 'Device info is not ready';

  @override
  String get cipherEstablishFailed => 'Failed to establish encryption';

  @override
  String get cipherEstablishingWait => 'Establishing encryption, please wait';

  @override
  String get cannotGetFileName => 'Could not get the file name';

  @override
  String sendFileFailed(String error) {
    return 'Failed to send file: $error';
  }

  @override
  String receiveFailed(String error) {
    return 'Failed to receive: $error';
  }

  @override
  String get waitingPeerAcceptFile => 'Waiting for the peer to accept the file';

  @override
  String get pleaseAcceptFileFirst => 'Accept the file first';

  @override
  String get fileTransferring => 'File is transferring';

  @override
  String get peerDeclinedFile => 'The peer declined this file';

  @override
  String get fileDeclined => 'File declined';

  @override
  String get fileTransferFailed => 'File transfer failed';

  @override
  String get localPathUnavailable => 'Local file path is unavailable';

  @override
  String get localFileMissing => 'The local file is missing or was moved';

  @override
  String get shareFailed => 'Share failed';

  @override
  String get saveFailed => 'Save failed';

  @override
  String get today => 'Today';

  @override
  String get yesterday => 'Yesterday';

  @override
  String get weekdayMon => 'Mon';

  @override
  String get weekdayTue => 'Tue';

  @override
  String get weekdayWed => 'Wed';

  @override
  String get weekdayThu => 'Thu';

  @override
  String get weekdayFri => 'Fri';

  @override
  String get weekdaySat => 'Sat';

  @override
  String get weekdaySun => 'Sun';

  @override
  String get cipherReadyTitle => 'End-to-end encryption is on';

  @override
  String get cipherReadySubtitle =>
      'Verify the public key with the other person';

  @override
  String get cipherEstablishing => 'Establishing encryption…';

  @override
  String get cipherFailed => 'Encryption failed';

  @override
  String get cipherWaiting => 'Waiting for encryption';

  @override
  String startChatWith(String name) {
    return 'Start a chat with $name';
  }

  @override
  String get startChatHint => 'Send text or files over a direct LAN connection';

  @override
  String get waitingPeerAccept => 'Waiting for the peer to accept';

  @override
  String get waitingYourAccept => 'Waiting for you to accept';

  @override
  String get transferring => 'Transferring…';

  @override
  String get transferDoneTapOpen => 'Transferred · tap to open';

  @override
  String get peerDeclined => 'Declined by peer';

  @override
  String get declined => 'Declined';

  @override
  String get transferFailed => 'Transfer failed';

  @override
  String get savedLocally => 'Saved locally';

  @override
  String get sendFile => 'Send file';

  @override
  String get messageHint => 'Message...';

  @override
  String get unknownSize => 'Unknown size';

  @override
  String get unknownFile => 'Unknown file';

  @override
  String get incomingFile => 'Incoming file';

  @override
  String get noAlbumPermission => 'Photo library access denied';

  @override
  String get savedToAlbum => 'Saved to album';

  @override
  String get notEnoughSpace => 'Not enough storage';

  @override
  String get unsupportedImageFormat => 'This image format is not supported';

  @override
  String get cannotDisplayImage => 'Unable to display image';

  @override
  String get cannotOpenPage => 'Unable to open page';

  @override
  String get errorConnectFailed => 'Failed to connect';

  @override
  String get errorCipherNotReady => 'Encryption channel is not ready';

  @override
  String get errorSendFailed => 'Failed to send message';

  @override
  String get errorNegotiateSendFailed => 'Failed to send handshake';

  @override
  String get errorPeerTempKeyInvalid =>
      'Peer\'s temporary public key is invalid';

  @override
  String get errorPeerIdentityInvalid =>
      'Peer\'s identity signature is invalid';

  @override
  String get errorPeerTempKeyVerifyFailed =>
      'Failed to verify peer\'s temporary public key';

  @override
  String get errorPeerIdentityMismatch =>
      'Peer identity does not match the known device';

  @override
  String get errorConfirmCipherEmpty => 'Key confirmation ciphertext is empty';

  @override
  String get errorConfirmMismatch =>
      'Key confirmation does not match the local temporary public key';

  @override
  String get errorConfirmDecryptFailed => 'Failed to decrypt key confirmation';

  @override
  String get errorNegotiateException => 'Key negotiation error';

  @override
  String get shareSendTitle => 'Send to';

  @override
  String get shareSendHint => 'Choose a device to send to';

  @override
  String get shareEncryptHint =>
      'Encryption is on. A key handshake will run before sending';

  @override
  String get shareSending => 'Sending…';

  @override
  String get shareNegotiating => 'Negotiating encryption…';

  @override
  String get shareSent => 'Sent';

  @override
  String get shareNothing => 'Nothing to send';

  @override
  String shareSendFailed(String error) {
    return 'Failed to send: $error';
  }
}
