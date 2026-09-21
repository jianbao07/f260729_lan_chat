import 'package:flutter/material.dart';
import 'package:yf_code/l10n/app_error_code.dart';
import 'package:yf_code/l10n/app_localizations.dart';

export 'package:yf_code/l10n/app_localizations.dart';

extension AppL10nX on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}

String relativeTimeLabel(BuildContext context, int? utcMs) {
  if (utcMs == null) return '';
  final l10n = context.l10n;
  final last = DateTime.fromMillisecondsSinceEpoch(utcMs, isUtc: true);
  final diff = DateTime.now().toUtc().difference(last);
  if (diff.inSeconds < 60) return l10n.justNow;
  if (diff.inMinutes < 60) return l10n.minutesAgo(diff.inMinutes);
  final local = last.toLocal();
  final now = DateTime.now();
  if (local.year == now.year && local.month == now.month && local.day == now.day) {
    return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }
  if (local.year == now.year) return '${local.month}/${local.day}';
  return '${local.year}/${local.month}/${local.day}';
}

String lastSeenLabel(BuildContext context, int? utcMs) {
  final l10n = context.l10n;
  if (utcMs == null) return l10n.unknown;
  final last = DateTime.fromMillisecondsSinceEpoch(utcMs, isUtc: true);
  final diff = DateTime.now().toUtc().difference(last);
  if (diff.inSeconds < 60) return l10n.justNow;
  if (diff.inMinutes < 60) return l10n.minutesAgo(diff.inMinutes);
  if (diff.inHours < 24) return l10n.hoursAgo(diff.inHours);
  if (diff.inDays < 7) return l10n.daysAgo(diff.inDays);
  return relativeTimeLabel(context, utcMs);
}

String weekdayLabel(AppLocalizations l10n, int weekday) {
  switch (weekday) {
    case DateTime.monday:
      return l10n.weekdayMon;
    case DateTime.tuesday:
      return l10n.weekdayTue;
    case DateTime.wednesday:
      return l10n.weekdayWed;
    case DateTime.thursday:
      return l10n.weekdayThu;
    case DateTime.friday:
      return l10n.weekdayFri;
    case DateTime.saturday:
      return l10n.weekdaySat;
    default:
      return l10n.weekdaySun;
  }
}

String localizeError(AppLocalizations l10n, String? code) {
  switch (code) {
    case AppErrorCode.connectFailed:
      return l10n.errorConnectFailed;
    case AppErrorCode.cipherNotReady:
      return l10n.errorCipherNotReady;
    case AppErrorCode.sendFailed:
      return l10n.errorSendFailed;
    case AppErrorCode.negotiateSendFailed:
      return l10n.errorNegotiateSendFailed;
    case AppErrorCode.peerTempKeyInvalid:
      return l10n.errorPeerTempKeyInvalid;
    case AppErrorCode.peerIdentityInvalid:
      return l10n.errorPeerIdentityInvalid;
    case AppErrorCode.peerTempKeyVerifyFailed:
      return l10n.errorPeerTempKeyVerifyFailed;
    case AppErrorCode.peerIdentityMismatch:
      return l10n.errorPeerIdentityMismatch;
    case AppErrorCode.confirmCipherEmpty:
      return l10n.errorConfirmCipherEmpty;
    case AppErrorCode.confirmMismatch:
      return l10n.errorConfirmMismatch;
    case AppErrorCode.confirmDecryptFailed:
      return l10n.errorConfirmDecryptFailed;
    case AppErrorCode.negotiateException:
      return l10n.errorNegotiateException;
    default:
      return (code == null || code.isEmpty) ? l10n.cipherEstablishFailed : code;
  }
}
