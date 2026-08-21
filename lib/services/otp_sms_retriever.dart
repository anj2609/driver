import 'package:pinput/pinput.dart';
import 'package:smart_auth/smart_auth.dart';

/// Fills the OTP field automatically from the verification SMS, so the driver
/// doesn't have to leave the app, memorise a code, and come back to type it.
///
/// Uses Android's **SMS User Consent API**, deliberately, rather than the SMS
/// Retriever API. The two are easy to confuse but have very different
/// requirements:
///
///  - *SMS Retriever* is fully silent, but only ever fires for an SMS whose
///    body ends with an 11-character hash unique to this app's signing key
///    (and different between debug and release builds). The backend has to
///    append that hash to every OTP message for it to work at all. This app
///    previously wired up `sms_autofill`, which uses exactly that API — with
///    no way to confirm the hash is in the messages our backend actually
///    sends, which is the most likely reason autofill never appeared.
///  - *User Consent* works with any unmodified SMS text. Android shows a
///    one-tap "Allow app to read this message?" dialog, and on approval hands
///    over the message body. Nothing about the backend has to change.
///
/// Given we can't change (or even verify) the OTP SMS format from here, User
/// Consent is the only one of the two that can be relied on to work.
///
/// Caveats worth knowing, both inherent to the platform API rather than to
/// this code: the listener only catches messages that arrive *after* it
/// starts, and Android ignores messages sent from a number in the user's own
/// contacts. Neither is fatal — the field stays fully typeable, which is
/// exactly how it behaved before.
class OtpSmsRetriever implements SmsRetriever {
  const OtpSmsRetriever();

  /// Exactly four digits, bounded so a longer number in the same message
  /// (a helpline, an order id) can't be mistaken for the code. Both apps'
  /// OTPs are 4-digit; Pinput additionally drops anything whose length
  /// doesn't match the field's, so a wrong-length match is discarded rather
  /// than half-filled.
  static const String _fourDigitCode = r'\b\d{4}\b';

  /// One code per screen visit. Resending issues a new SMS, but this screen
  /// re-registers its listener at that point anyway, so there's nothing to
  /// gain from keeping a long-lived listener open — and a stale one firing
  /// later would overwrite whatever the driver had since typed by hand.
  @override
  bool get listenForMultipleSms => false;

  @override
  Future<String?> getSmsCode() async {
    final result = await SmartAuth.instance.getSmsWithUserConsentApi(
      matcher: _fourDigitCode,
    );
    // Covers all three outcomes the API distinguishes — success, failure, and
    // the driver dismissing the consent dialog — without treating a dismissal
    // as an error worth surfacing. Declining just means they'd rather type it.
    return result.hasData ? result.data?.code : null;
  }

  @override
  Future<void> dispose() async {
    await SmartAuth.instance.removeUserConsentApiListener();
  }
}
