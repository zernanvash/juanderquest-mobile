import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';

import '../../../core/l10n/app_language.dart';

const sukiPassPrefix = 'JDQSUKIPASS:';

/// Plan 107 §6.6: what the counter scanner accepts. Returns the code to send
/// to `POST /merchant/suki/scan`, or null for anything else.
///
/// - `JDQSUKIPASS:<jwt>`: the prefix is matched case-insensitively and
///   normalised; the JWT keeps its case (it is signed).
/// - `SUKI-…` reward codes and `JDQ-…` voucher/perk codes: case-insensitive,
///   spaces removed (typed codes work), returned upper case.
String? extractCounterCode(String? raw) {
  final text = raw?.trim();
  if (text == null || text.isEmpty) return null;
  if (text.toUpperCase().startsWith(sukiPassPrefix)) {
    final jwt = text.substring(sukiPassPrefix.length).trim();
    return jwt.isEmpty ? null : '$sukiPassPrefix$jwt';
  }
  final code = text.replaceAll(RegExp(r'\s+'), '').toUpperCase();
  if (RegExp(r'^(SUKI|JDQ)-[A-Z0-9-]{4,60}$').hasMatch(code)) return code;
  return null;
}

/// The API error code (`error.code`) of a failed call, or ''.
String merchantSukiErrorCode(Object? error) {
  if (error is DioException) {
    final body = error.response?.data;
    if (body is Map && body['error'] is Map) {
      return '${body['error']['code'] ?? ''}';
    }
  }
  return '';
}

bool isSukiDisabled(Object? error) =>
    merchantSukiErrorCode(error) == 'SUKI_DISABLED' ||
    (error is DioException && error.response?.statusCode == 503);

/// Plain-language copy for the merchant side (§7.3 plus the counter codes).
String merchantSukiErrorText(BuildContext context, Object? error) {
  final code = merchantSukiErrorCode(error);
  switch (code) {
    case 'SUKI_DISABLED':
      return tr(context,
          en: 'Suki Cards are coming soon.', tl: 'Malapit na ang Suki Cards.');
    case 'MERCHANT_OWNER_REQUIRED':
      return tr(context,
          en: 'Only the shop owner can change the Suki Card.',
          tl: 'Ang may-ari lang ang makakapagbago ng Suki Card.');
    case 'SHOP_LOCATION_MISSING':
      return tr(context,
          en: 'Pin your shop location first.',
          tl: 'I-pin muna ang lokasyon ng tindahan.');
    case 'SHOP_NOT_PUBLISHED':
      return tr(context,
          en: 'Publish your shop profile first.',
          tl: 'I-publish muna ang profile ng tindahan.');
    case 'SUKI_ADMIN_PAUSED':
      return tr(context,
          en: 'Your LGU tourism office paused this Suki Card.',
          tl: 'Pinahinto ng LGU tourism office ang Suki Card na ito.');
    case 'LOCATION_ACCURACY_TOO_LOW':
      return tr(context,
          en: 'Your GPS is weak. Stand at the counter, wait a moment and try again.',
          tl: 'Mahina ang GPS. Subukang muli.');
    case 'PASS_EXPIRED':
      return tr(context,
          en: 'This pass expired. Ask the customer to show a new one.',
          tl: 'Expired na ang pass. Humingi ng bago.');
    case 'PASS_USED':
      return tr(context,
          en: 'This pass was already used.', tl: 'Nagamit na ang pass na ito.');
    case 'PASS_OTHER_SHOP':
      return tr(context,
          en: 'This pass is for a different shop.',
          tl: 'Para sa ibang tindahan ang pass na ito.');
    case 'PASS_INVALID':
      return tr(context,
          en: 'That pass is not valid.', tl: 'Hindi valid ang pass.');
    case 'ALREADY_VISITED_TODAY':
      return tr(context,
          en: 'This customer already has a visit today.',
          tl: 'May bisita na ang customer ngayong araw.');
    case 'SELF_VISIT_FORBIDDEN':
      return tr(context,
          en: 'Shop members cannot collect visits at their own shop.',
          tl: 'Hindi puwedeng mag-bisita sa sariling tindahan.');
    case 'EMAIL_NOT_VERIFIED':
      return tr(context,
          en: 'The customer must verify their email first.',
          tl: 'Kailangang i-verify muna ng customer ang email.');
    case 'SUKI_NOT_ACTIVE':
      return tr(context,
          en: 'Your Suki Card is not active.',
          tl: 'Hindi aktibo ang Suki Card mo.');
    case 'REWARD_NOT_FOUND':
      return tr(context,
          en: 'That reward is not for this shop.',
          tl: 'Hindi para sa tindahang ito ang reward.');
    case 'REWARD_ALREADY_CLAIMED':
      return tr(context,
          en: 'This reward was already claimed.',
          tl: 'Nakuha na ang reward na ito.');
    case 'REWARD_EXPIRED':
      return tr(context,
          en: 'This reward has expired.', tl: 'Expired na ang reward.');
    case 'CODE_NOT_FOUND':
      return tr(context,
          en: 'That voucher is not for this shop.',
          tl: 'Hindi para sa tindahang ito ang voucher.');
    case 'CODE_ALREADY_USED':
      return tr(context,
          en: 'This voucher was already used.',
          tl: 'Nagamit na ang voucher na ito.');
    case 'CODE_UNKNOWN':
      return tr(context,
          en: 'That is not a JuanderQuest code.',
          tl: 'Hindi ito JuanderQuest code.');
  }
  if (error is DioException) {
    if (error.response?.statusCode == 503) {
      return tr(context,
          en: 'Suki Cards are coming soon.', tl: 'Malapit na ang Suki Cards.');
    }
    final body = error.response?.data;
    final message = body is Map && body['error'] is Map
        ? '${body['error']['message'] ?? ''}'
        : '';
    if (message.isNotEmpty) return message;
  }
  return tr(context,
      en: 'Something went wrong. Check your connection and try again.',
      tl: 'May mali. Suriin ang koneksyon at subukang muli.');
}
