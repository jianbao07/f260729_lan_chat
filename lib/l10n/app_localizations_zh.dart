// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appName => '内网通';

  @override
  String get appTagline => '局域网即时通讯';

  @override
  String get tabChats => '会话';

  @override
  String get tabDevices => '设备';

  @override
  String get tabMe => '我的';

  @override
  String get lanDevices => '局域网设备';

  @override
  String get unknownDevice => '未知设备';

  @override
  String get unknown => '未知';

  @override
  String get copy => '复制';

  @override
  String get copied => '已复制';

  @override
  String get close => '关闭';

  @override
  String get share => '分享';

  @override
  String get save => '保存';

  @override
  String get saveAs => '另存为';

  @override
  String get saved => '已保存';

  @override
  String get retry => '重试';

  @override
  String get resend => '重新发送';

  @override
  String get online => '在线';

  @override
  String get offline => '离线';

  @override
  String get file => '文件';

  @override
  String get image => '图片';

  @override
  String get me => '我';

  @override
  String get thisDevice => '本机';

  @override
  String get accept => '接收';

  @override
  String get decline => '拒绝';

  @override
  String get justNow => '刚刚';

  @override
  String minutesAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 分钟前',
    );
    return '$_temp0';
  }

  @override
  String hoursAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 小时前',
    );
    return '$_temp0';
  }

  @override
  String daysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 天前',
    );
    return '$_temp0';
  }

  @override
  String get deviceNotFound => '找不到该设备信息';

  @override
  String get noConversations => '暂时没有会话';

  @override
  String get noConversationsHint => '发现在线设备后，向他打个招呼吧';

  @override
  String get noMessages => '暂无消息';

  @override
  String scanDone(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '扫描完成，共发现 $count 台设备',
    );
    return '$_temp0';
  }

  @override
  String subnetSuffix(String cidr) {
    return ' · 网段 $cidr';
  }

  @override
  String onlineCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 台在线',
    );
    return '$_temp0';
  }

  @override
  String get noOnlineDevices => '暂无在线设备';

  @override
  String get noOnlineDevicesHint => '确保对方已打开应用，并连接到同一网络';

  @override
  String deviceNameLabel(String name) {
    return '设备名 $name';
  }

  @override
  String get sectionDeviceInfo => '本机信息';

  @override
  String get nickname => '昵称';

  @override
  String get tapToSetNickname => '点击设置昵称';

  @override
  String get nicknameCleared => '已清除昵称';

  @override
  String get nicknameSaved => '昵称已保存';

  @override
  String get ipAddress => 'IP 地址';

  @override
  String get deviceId => '设备 ID';

  @override
  String get publicKey => '公钥';

  @override
  String get sectionGeneral => '通用设置';

  @override
  String get theme => '主题';

  @override
  String get language => '语言';

  @override
  String get notifications => '消息通知';

  @override
  String get discoverable => '允许被局域网发现';

  @override
  String get encryptTransfer => '加密传输';

  @override
  String get sectionAbout => '关于';

  @override
  String get version => '版本号';

  @override
  String get privacyPolicy => '隐私政策';

  @override
  String get userAgreement => '用户协议';

  @override
  String get helpFeedback => '帮助与反馈';

  @override
  String get themeSystem => '系统';

  @override
  String get themeDark => '深色';

  @override
  String get themeLight => '浅色';

  @override
  String get localeSystem => '系统';

  @override
  String get localeZh => '中文';

  @override
  String get localeEn => 'English';

  @override
  String get profileTitle => '详细资料';

  @override
  String originalName(String name) {
    return '原名 $name';
  }

  @override
  String get remark => '备注';

  @override
  String get tapToSetRemark => '点击设置备注';

  @override
  String get remarkCleared => '已清除备注';

  @override
  String get remarkSaved => '备注已保存';

  @override
  String get sendMessage => '发送消息';

  @override
  String offlineLastSeen(String time) {
    return '离线 · 最后在线 $time';
  }

  @override
  String get peerAddressInvalid => '对方地址无效，无法发送';

  @override
  String get deviceNotReady => '设备信息未就绪，无法发送';

  @override
  String get cipherEstablishFailed => '加密通道建立失败';

  @override
  String get cipherEstablishingWait => '正在建立加密通道，请稍候';

  @override
  String get cannotGetFileName => '无法获取文件名';

  @override
  String sendFileFailed(String error) {
    return '发送文件失败：$error';
  }

  @override
  String receiveFailed(String error) {
    return '接收失败：$error';
  }

  @override
  String get waitingPeerAcceptFile => '等待对方接收文件';

  @override
  String get pleaseAcceptFileFirst => '请先接收文件';

  @override
  String get fileTransferring => '文件正在传输中';

  @override
  String get peerDeclinedFile => '对方已拒绝该文件';

  @override
  String get fileDeclined => '已拒绝该文件';

  @override
  String get fileTransferFailed => '文件传输失败';

  @override
  String get localPathUnavailable => '本地文件路径不可用';

  @override
  String get localFileMissing => '本地文件不存在或已被移动';

  @override
  String get shareFailed => '分享失败';

  @override
  String get saveFailed => '保存失败';

  @override
  String get today => '今天';

  @override
  String get yesterday => '昨天';

  @override
  String get weekdayMon => '周一';

  @override
  String get weekdayTue => '周二';

  @override
  String get weekdayWed => '周三';

  @override
  String get weekdayThu => '周四';

  @override
  String get weekdayFri => '周五';

  @override
  String get weekdaySat => '周六';

  @override
  String get weekdaySun => '周日';

  @override
  String get cipherReadyTitle => '端到端加密已启用';

  @override
  String get cipherReadySubtitle => '请与对方核实公钥是否一致';

  @override
  String get cipherEstablishing => '正在建立加密通道…';

  @override
  String get cipherFailed => '加密建立失败';

  @override
  String get cipherWaiting => '等待加密连接';

  @override
  String startChatWith(String name) {
    return '与 $name 开始对话';
  }

  @override
  String get startChatHint => '可发送文字或文件，经局域网直连送达';

  @override
  String get waitingPeerAccept => '等待对方接收';

  @override
  String get waitingYourAccept => '待你确认接收';

  @override
  String get transferring => '正在传输…';

  @override
  String get transferDoneTapOpen => '传输完成 · 点击打开';

  @override
  String get peerDeclined => '对方已拒绝';

  @override
  String get declined => '已拒绝';

  @override
  String get transferFailed => '传输失败';

  @override
  String get savedLocally => '已保存至本地';

  @override
  String get sendFile => '发送文件';

  @override
  String get messageHint => '发送消息...';

  @override
  String get unknownSize => '未知大小';

  @override
  String get unknownFile => '未知文件';

  @override
  String get incomingFile => '收到文件';

  @override
  String get noAlbumPermission => '没有相册权限';

  @override
  String get savedToAlbum => '已保存到相册';

  @override
  String get notEnoughSpace => '存储空间不足';

  @override
  String get unsupportedImageFormat => '不支持该图片格式';

  @override
  String get cannotDisplayImage => '无法显示图片';

  @override
  String get cannotOpenPage => '无法打开页面';

  @override
  String get errorConnectFailed => '连接建立失败';

  @override
  String get errorCipherNotReady => '加密通道未就绪';

  @override
  String get errorSendFailed => '消息发送失败';

  @override
  String get errorNegotiateSendFailed => '协商消息发送失败';

  @override
  String get errorPeerTempKeyInvalid => '对方临时公钥无效';

  @override
  String get errorPeerIdentityInvalid => '对方身份签名无效';

  @override
  String get errorPeerTempKeyVerifyFailed => '对方临时公钥验签失败';

  @override
  String get errorPeerIdentityMismatch => '对方身份与已知设备不符';

  @override
  String get errorConfirmCipherEmpty => '密钥确认密文为空';

  @override
  String get errorConfirmMismatch => '密钥确认与本地临时公钥不一致';

  @override
  String get errorConfirmDecryptFailed => '密钥确认解密失败';

  @override
  String get errorNegotiateException => '密钥协商异常';
}
