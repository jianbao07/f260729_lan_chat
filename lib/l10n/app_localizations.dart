import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('zh'),
    Locale('en'),
  ];

  /// No description provided for @appName.
  ///
  /// In zh, this message translates to:
  /// **'内网通'**
  String get appName;

  /// No description provided for @appTagline.
  ///
  /// In zh, this message translates to:
  /// **'局域网即时通讯'**
  String get appTagline;

  /// No description provided for @tabChats.
  ///
  /// In zh, this message translates to:
  /// **'会话'**
  String get tabChats;

  /// No description provided for @tabDevices.
  ///
  /// In zh, this message translates to:
  /// **'设备'**
  String get tabDevices;

  /// No description provided for @tabMe.
  ///
  /// In zh, this message translates to:
  /// **'我的'**
  String get tabMe;

  /// No description provided for @lanDevices.
  ///
  /// In zh, this message translates to:
  /// **'局域网设备'**
  String get lanDevices;

  /// No description provided for @unknownDevice.
  ///
  /// In zh, this message translates to:
  /// **'未知设备'**
  String get unknownDevice;

  /// No description provided for @unknown.
  ///
  /// In zh, this message translates to:
  /// **'未知'**
  String get unknown;

  /// No description provided for @copy.
  ///
  /// In zh, this message translates to:
  /// **'复制'**
  String get copy;

  /// No description provided for @copied.
  ///
  /// In zh, this message translates to:
  /// **'已复制'**
  String get copied;

  /// No description provided for @close.
  ///
  /// In zh, this message translates to:
  /// **'关闭'**
  String get close;

  /// No description provided for @share.
  ///
  /// In zh, this message translates to:
  /// **'分享'**
  String get share;

  /// No description provided for @save.
  ///
  /// In zh, this message translates to:
  /// **'保存'**
  String get save;

  /// No description provided for @saveAs.
  ///
  /// In zh, this message translates to:
  /// **'另存为'**
  String get saveAs;

  /// No description provided for @saved.
  ///
  /// In zh, this message translates to:
  /// **'已保存'**
  String get saved;

  /// No description provided for @retry.
  ///
  /// In zh, this message translates to:
  /// **'重试'**
  String get retry;

  /// No description provided for @resend.
  ///
  /// In zh, this message translates to:
  /// **'重新发送'**
  String get resend;

  /// No description provided for @online.
  ///
  /// In zh, this message translates to:
  /// **'在线'**
  String get online;

  /// No description provided for @offline.
  ///
  /// In zh, this message translates to:
  /// **'离线'**
  String get offline;

  /// No description provided for @file.
  ///
  /// In zh, this message translates to:
  /// **'文件'**
  String get file;

  /// No description provided for @image.
  ///
  /// In zh, this message translates to:
  /// **'图片'**
  String get image;

  /// No description provided for @me.
  ///
  /// In zh, this message translates to:
  /// **'我'**
  String get me;

  /// No description provided for @thisDevice.
  ///
  /// In zh, this message translates to:
  /// **'本机'**
  String get thisDevice;

  /// No description provided for @accept.
  ///
  /// In zh, this message translates to:
  /// **'接收'**
  String get accept;

  /// No description provided for @decline.
  ///
  /// In zh, this message translates to:
  /// **'拒绝'**
  String get decline;

  /// No description provided for @justNow.
  ///
  /// In zh, this message translates to:
  /// **'刚刚'**
  String get justNow;

  /// No description provided for @minutesAgo.
  ///
  /// In zh, this message translates to:
  /// **'{count, plural, other{{count} 分钟前}}'**
  String minutesAgo(int count);

  /// No description provided for @hoursAgo.
  ///
  /// In zh, this message translates to:
  /// **'{count, plural, other{{count} 小时前}}'**
  String hoursAgo(int count);

  /// No description provided for @daysAgo.
  ///
  /// In zh, this message translates to:
  /// **'{count, plural, other{{count} 天前}}'**
  String daysAgo(int count);

  /// No description provided for @deviceNotFound.
  ///
  /// In zh, this message translates to:
  /// **'找不到该设备信息'**
  String get deviceNotFound;

  /// No description provided for @noConversations.
  ///
  /// In zh, this message translates to:
  /// **'暂时没有会话'**
  String get noConversations;

  /// No description provided for @noConversationsHint.
  ///
  /// In zh, this message translates to:
  /// **'发现在线设备后，向他打个招呼吧'**
  String get noConversationsHint;

  /// No description provided for @noMessages.
  ///
  /// In zh, this message translates to:
  /// **'暂无消息'**
  String get noMessages;

  /// No description provided for @scanDone.
  ///
  /// In zh, this message translates to:
  /// **'{count, plural, other{扫描完成，共发现 {count} 台设备}}'**
  String scanDone(int count);

  /// No description provided for @subnetSuffix.
  ///
  /// In zh, this message translates to:
  /// **' · 网段 {cidr}'**
  String subnetSuffix(String cidr);

  /// No description provided for @onlineCount.
  ///
  /// In zh, this message translates to:
  /// **'{count, plural, other{{count} 台在线}}'**
  String onlineCount(int count);

  /// No description provided for @noOnlineDevices.
  ///
  /// In zh, this message translates to:
  /// **'暂无在线设备'**
  String get noOnlineDevices;

  /// No description provided for @noOnlineDevicesHint.
  ///
  /// In zh, this message translates to:
  /// **'确保对方已打开应用，并连接到同一网络'**
  String get noOnlineDevicesHint;

  /// No description provided for @deviceNameLabel.
  ///
  /// In zh, this message translates to:
  /// **'设备名 {name}'**
  String deviceNameLabel(String name);

  /// No description provided for @sectionDeviceInfo.
  ///
  /// In zh, this message translates to:
  /// **'本机信息'**
  String get sectionDeviceInfo;

  /// No description provided for @nickname.
  ///
  /// In zh, this message translates to:
  /// **'昵称'**
  String get nickname;

  /// No description provided for @tapToSetNickname.
  ///
  /// In zh, this message translates to:
  /// **'点击设置昵称'**
  String get tapToSetNickname;

  /// No description provided for @nicknameCleared.
  ///
  /// In zh, this message translates to:
  /// **'已清除昵称'**
  String get nicknameCleared;

  /// No description provided for @nicknameSaved.
  ///
  /// In zh, this message translates to:
  /// **'昵称已保存'**
  String get nicknameSaved;

  /// No description provided for @ipAddress.
  ///
  /// In zh, this message translates to:
  /// **'IP 地址'**
  String get ipAddress;

  /// No description provided for @deviceId.
  ///
  /// In zh, this message translates to:
  /// **'设备 ID'**
  String get deviceId;

  /// No description provided for @publicKey.
  ///
  /// In zh, this message translates to:
  /// **'公钥'**
  String get publicKey;

  /// No description provided for @sectionGeneral.
  ///
  /// In zh, this message translates to:
  /// **'通用设置'**
  String get sectionGeneral;

  /// No description provided for @theme.
  ///
  /// In zh, this message translates to:
  /// **'主题'**
  String get theme;

  /// No description provided for @language.
  ///
  /// In zh, this message translates to:
  /// **'语言'**
  String get language;

  /// No description provided for @notifications.
  ///
  /// In zh, this message translates to:
  /// **'消息通知'**
  String get notifications;

  /// No description provided for @discoverable.
  ///
  /// In zh, this message translates to:
  /// **'允许被局域网发现'**
  String get discoverable;

  /// No description provided for @encryptTransfer.
  ///
  /// In zh, this message translates to:
  /// **'加密传输'**
  String get encryptTransfer;

  /// No description provided for @sectionAbout.
  ///
  /// In zh, this message translates to:
  /// **'关于'**
  String get sectionAbout;

  /// No description provided for @version.
  ///
  /// In zh, this message translates to:
  /// **'版本号'**
  String get version;

  /// No description provided for @privacyPolicy.
  ///
  /// In zh, this message translates to:
  /// **'隐私政策'**
  String get privacyPolicy;

  /// No description provided for @userAgreement.
  ///
  /// In zh, this message translates to:
  /// **'用户协议'**
  String get userAgreement;

  /// No description provided for @helpFeedback.
  ///
  /// In zh, this message translates to:
  /// **'帮助与反馈'**
  String get helpFeedback;

  /// No description provided for @themeSystem.
  ///
  /// In zh, this message translates to:
  /// **'系统'**
  String get themeSystem;

  /// No description provided for @themeDark.
  ///
  /// In zh, this message translates to:
  /// **'深色'**
  String get themeDark;

  /// No description provided for @themeLight.
  ///
  /// In zh, this message translates to:
  /// **'浅色'**
  String get themeLight;

  /// No description provided for @localeSystem.
  ///
  /// In zh, this message translates to:
  /// **'系统'**
  String get localeSystem;

  /// No description provided for @localeZh.
  ///
  /// In zh, this message translates to:
  /// **'中文'**
  String get localeZh;

  /// No description provided for @localeEn.
  ///
  /// In zh, this message translates to:
  /// **'English'**
  String get localeEn;

  /// No description provided for @profileTitle.
  ///
  /// In zh, this message translates to:
  /// **'详细资料'**
  String get profileTitle;

  /// No description provided for @originalName.
  ///
  /// In zh, this message translates to:
  /// **'原名 {name}'**
  String originalName(String name);

  /// No description provided for @remark.
  ///
  /// In zh, this message translates to:
  /// **'备注'**
  String get remark;

  /// No description provided for @tapToSetRemark.
  ///
  /// In zh, this message translates to:
  /// **'点击设置备注'**
  String get tapToSetRemark;

  /// No description provided for @remarkCleared.
  ///
  /// In zh, this message translates to:
  /// **'已清除备注'**
  String get remarkCleared;

  /// No description provided for @remarkSaved.
  ///
  /// In zh, this message translates to:
  /// **'备注已保存'**
  String get remarkSaved;

  /// No description provided for @sendMessage.
  ///
  /// In zh, this message translates to:
  /// **'发送消息'**
  String get sendMessage;

  /// No description provided for @offlineLastSeen.
  ///
  /// In zh, this message translates to:
  /// **'离线 · 最后在线 {time}'**
  String offlineLastSeen(String time);

  /// No description provided for @peerAddressInvalid.
  ///
  /// In zh, this message translates to:
  /// **'对方地址无效，无法发送'**
  String get peerAddressInvalid;

  /// No description provided for @deviceNotReady.
  ///
  /// In zh, this message translates to:
  /// **'设备信息未就绪，无法发送'**
  String get deviceNotReady;

  /// No description provided for @cipherEstablishFailed.
  ///
  /// In zh, this message translates to:
  /// **'加密通道建立失败'**
  String get cipherEstablishFailed;

  /// No description provided for @cipherEstablishingWait.
  ///
  /// In zh, this message translates to:
  /// **'正在建立加密通道，请稍候'**
  String get cipherEstablishingWait;

  /// No description provided for @cannotGetFileName.
  ///
  /// In zh, this message translates to:
  /// **'无法获取文件名'**
  String get cannotGetFileName;

  /// No description provided for @sendFileFailed.
  ///
  /// In zh, this message translates to:
  /// **'发送文件失败：{error}'**
  String sendFileFailed(String error);

  /// No description provided for @receiveFailed.
  ///
  /// In zh, this message translates to:
  /// **'接收失败：{error}'**
  String receiveFailed(String error);

  /// No description provided for @waitingPeerAcceptFile.
  ///
  /// In zh, this message translates to:
  /// **'等待对方接收文件'**
  String get waitingPeerAcceptFile;

  /// No description provided for @pleaseAcceptFileFirst.
  ///
  /// In zh, this message translates to:
  /// **'请先接收文件'**
  String get pleaseAcceptFileFirst;

  /// No description provided for @fileTransferring.
  ///
  /// In zh, this message translates to:
  /// **'文件正在传输中'**
  String get fileTransferring;

  /// No description provided for @peerDeclinedFile.
  ///
  /// In zh, this message translates to:
  /// **'对方已拒绝该文件'**
  String get peerDeclinedFile;

  /// No description provided for @fileDeclined.
  ///
  /// In zh, this message translates to:
  /// **'已拒绝该文件'**
  String get fileDeclined;

  /// No description provided for @fileTransferFailed.
  ///
  /// In zh, this message translates to:
  /// **'文件传输失败'**
  String get fileTransferFailed;

  /// No description provided for @localPathUnavailable.
  ///
  /// In zh, this message translates to:
  /// **'本地文件路径不可用'**
  String get localPathUnavailable;

  /// No description provided for @localFileMissing.
  ///
  /// In zh, this message translates to:
  /// **'本地文件不存在或已被移动'**
  String get localFileMissing;

  /// No description provided for @shareFailed.
  ///
  /// In zh, this message translates to:
  /// **'分享失败'**
  String get shareFailed;

  /// No description provided for @saveFailed.
  ///
  /// In zh, this message translates to:
  /// **'保存失败'**
  String get saveFailed;

  /// No description provided for @today.
  ///
  /// In zh, this message translates to:
  /// **'今天'**
  String get today;

  /// No description provided for @yesterday.
  ///
  /// In zh, this message translates to:
  /// **'昨天'**
  String get yesterday;

  /// No description provided for @weekdayMon.
  ///
  /// In zh, this message translates to:
  /// **'周一'**
  String get weekdayMon;

  /// No description provided for @weekdayTue.
  ///
  /// In zh, this message translates to:
  /// **'周二'**
  String get weekdayTue;

  /// No description provided for @weekdayWed.
  ///
  /// In zh, this message translates to:
  /// **'周三'**
  String get weekdayWed;

  /// No description provided for @weekdayThu.
  ///
  /// In zh, this message translates to:
  /// **'周四'**
  String get weekdayThu;

  /// No description provided for @weekdayFri.
  ///
  /// In zh, this message translates to:
  /// **'周五'**
  String get weekdayFri;

  /// No description provided for @weekdaySat.
  ///
  /// In zh, this message translates to:
  /// **'周六'**
  String get weekdaySat;

  /// No description provided for @weekdaySun.
  ///
  /// In zh, this message translates to:
  /// **'周日'**
  String get weekdaySun;

  /// No description provided for @cipherReadyTitle.
  ///
  /// In zh, this message translates to:
  /// **'端到端加密已启用'**
  String get cipherReadyTitle;

  /// No description provided for @cipherReadySubtitle.
  ///
  /// In zh, this message translates to:
  /// **'请与对方核实公钥是否一致'**
  String get cipherReadySubtitle;

  /// No description provided for @cipherEstablishing.
  ///
  /// In zh, this message translates to:
  /// **'正在建立加密通道…'**
  String get cipherEstablishing;

  /// No description provided for @cipherFailed.
  ///
  /// In zh, this message translates to:
  /// **'加密建立失败'**
  String get cipherFailed;

  /// No description provided for @cipherWaiting.
  ///
  /// In zh, this message translates to:
  /// **'等待加密连接'**
  String get cipherWaiting;

  /// No description provided for @startChatWith.
  ///
  /// In zh, this message translates to:
  /// **'与 {name} 开始对话'**
  String startChatWith(String name);

  /// No description provided for @startChatHint.
  ///
  /// In zh, this message translates to:
  /// **'可发送文字或文件，经局域网直连送达'**
  String get startChatHint;

  /// No description provided for @waitingPeerAccept.
  ///
  /// In zh, this message translates to:
  /// **'等待对方接收'**
  String get waitingPeerAccept;

  /// No description provided for @waitingYourAccept.
  ///
  /// In zh, this message translates to:
  /// **'待你确认接收'**
  String get waitingYourAccept;

  /// No description provided for @transferring.
  ///
  /// In zh, this message translates to:
  /// **'正在传输…'**
  String get transferring;

  /// No description provided for @transferDoneTapOpen.
  ///
  /// In zh, this message translates to:
  /// **'传输完成 · 点击打开'**
  String get transferDoneTapOpen;

  /// No description provided for @peerDeclined.
  ///
  /// In zh, this message translates to:
  /// **'对方已拒绝'**
  String get peerDeclined;

  /// No description provided for @declined.
  ///
  /// In zh, this message translates to:
  /// **'已拒绝'**
  String get declined;

  /// No description provided for @transferFailed.
  ///
  /// In zh, this message translates to:
  /// **'传输失败'**
  String get transferFailed;

  /// No description provided for @savedLocally.
  ///
  /// In zh, this message translates to:
  /// **'已保存至本地'**
  String get savedLocally;

  /// No description provided for @sendFile.
  ///
  /// In zh, this message translates to:
  /// **'发送文件'**
  String get sendFile;

  /// No description provided for @messageHint.
  ///
  /// In zh, this message translates to:
  /// **'发送消息...'**
  String get messageHint;

  /// No description provided for @unknownSize.
  ///
  /// In zh, this message translates to:
  /// **'未知大小'**
  String get unknownSize;

  /// No description provided for @unknownFile.
  ///
  /// In zh, this message translates to:
  /// **'未知文件'**
  String get unknownFile;

  /// No description provided for @incomingFile.
  ///
  /// In zh, this message translates to:
  /// **'收到文件'**
  String get incomingFile;

  /// No description provided for @noAlbumPermission.
  ///
  /// In zh, this message translates to:
  /// **'没有相册权限'**
  String get noAlbumPermission;

  /// No description provided for @savedToAlbum.
  ///
  /// In zh, this message translates to:
  /// **'已保存到相册'**
  String get savedToAlbum;

  /// No description provided for @notEnoughSpace.
  ///
  /// In zh, this message translates to:
  /// **'存储空间不足'**
  String get notEnoughSpace;

  /// No description provided for @unsupportedImageFormat.
  ///
  /// In zh, this message translates to:
  /// **'不支持该图片格式'**
  String get unsupportedImageFormat;

  /// No description provided for @cannotDisplayImage.
  ///
  /// In zh, this message translates to:
  /// **'无法显示图片'**
  String get cannotDisplayImage;

  /// No description provided for @cannotOpenPage.
  ///
  /// In zh, this message translates to:
  /// **'无法打开页面'**
  String get cannotOpenPage;

  /// No description provided for @errorConnectFailed.
  ///
  /// In zh, this message translates to:
  /// **'连接建立失败'**
  String get errorConnectFailed;

  /// No description provided for @errorCipherNotReady.
  ///
  /// In zh, this message translates to:
  /// **'加密通道未就绪'**
  String get errorCipherNotReady;

  /// No description provided for @errorSendFailed.
  ///
  /// In zh, this message translates to:
  /// **'消息发送失败'**
  String get errorSendFailed;

  /// No description provided for @errorNegotiateSendFailed.
  ///
  /// In zh, this message translates to:
  /// **'协商消息发送失败'**
  String get errorNegotiateSendFailed;

  /// No description provided for @errorPeerTempKeyInvalid.
  ///
  /// In zh, this message translates to:
  /// **'对方临时公钥无效'**
  String get errorPeerTempKeyInvalid;

  /// No description provided for @errorPeerIdentityInvalid.
  ///
  /// In zh, this message translates to:
  /// **'对方身份签名无效'**
  String get errorPeerIdentityInvalid;

  /// No description provided for @errorPeerTempKeyVerifyFailed.
  ///
  /// In zh, this message translates to:
  /// **'对方临时公钥验签失败'**
  String get errorPeerTempKeyVerifyFailed;

  /// No description provided for @errorPeerIdentityMismatch.
  ///
  /// In zh, this message translates to:
  /// **'对方身份与已知设备不符'**
  String get errorPeerIdentityMismatch;

  /// No description provided for @errorConfirmCipherEmpty.
  ///
  /// In zh, this message translates to:
  /// **'密钥确认密文为空'**
  String get errorConfirmCipherEmpty;

  /// No description provided for @errorConfirmMismatch.
  ///
  /// In zh, this message translates to:
  /// **'密钥确认与本地临时公钥不一致'**
  String get errorConfirmMismatch;

  /// No description provided for @errorConfirmDecryptFailed.
  ///
  /// In zh, this message translates to:
  /// **'密钥确认解密失败'**
  String get errorConfirmDecryptFailed;

  /// No description provided for @errorNegotiateException.
  ///
  /// In zh, this message translates to:
  /// **'密钥协商异常'**
  String get errorNegotiateException;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
