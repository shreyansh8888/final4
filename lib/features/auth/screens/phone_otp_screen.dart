import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pin_code_fields/pin_code_fields.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/firebase_service.dart';
import '../../../navigation/app_router.dart';
import '../widgets/gradient_header.dart';

/// Phone OTP sign-in (Firebase Phone Authentication).
///
/// Requirements on the Firebase side (see FIREBASE_SETUP.md):
///  * Phone provider enabled in Authentication -> Sign-in method
///  * SHA-1 and SHA-256 of the signing key added to the Android app
///  * google-services.json re-downloaded after adding them
class PhoneOtpScreen extends ConsumerStatefulWidget {
  const PhoneOtpScreen({super.key});

  @override
  ConsumerState<PhoneOtpScreen> createState() => _PhoneOtpScreenState();
}

class _PhoneOtpScreenState extends ConsumerState<PhoneOtpScreen> {
  final _phoneCtrl = TextEditingController();
  String _otp = '';
  bool _otpSent = false;
  bool _loading = false;
  String? _errorMessage;
  String? _errorCode;
  int _resendSeconds = 0;
  Timer? _timer;

  final _firebase = FirebaseService.instance;

  @override
  void dispose() {
    _timer?.cancel();
    _phoneCtrl.dispose();
    super.dispose();
  }

  void _startResendTimer() {
    _timer?.cancel();
    setState(() => _resendSeconds = 30);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() => _resendSeconds--);
      if (_resendSeconds <= 0) t.cancel();
    });
  }

  String get _e164 {
    final digits = _phoneCtrl.text.replaceAll(RegExp(r'[^0-9]'), '');
    return '+91$digits';
  }

  Future<void> _sendOtp({bool resend = false}) async {
    final digits = _phoneCtrl.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length != 10) {
      setState(() {
        _errorMessage = context.tr('Enter a valid 10-digit phone number');
        _errorCode = null;
      });
      return;
    }

    setState(() {
      _loading = true;
      _errorMessage = null;
      _errorCode = null;
    });

    final result = await _firebase.sendOtp(_e164, resend: resend);
    if (!mounted) return;

    final code = _firebase.lastOtpErrorCode;

    switch (result) {
      case OtpSendResult.success:
        setState(() {
          _otpSent = true;
          _loading = false;
        });
        _startResendTimer();
        break;
      case OtpSendResult.autoVerified:
        // Signed in automatically (SMS auto-retrieval). Router redirects.
        setState(() => _loading = false);
        context.go(AppRoutes.home);
        break;
      case OtpSendResult.invalidPhone:
        _fail('Invalid phone number. Check and try again.', code);
        break;
      case OtpSendResult.tooManyRequests:
        _fail('Too many attempts. Please try after some time.', code);
        break;
      case OtpSendResult.network:
        _fail('Network error. Please check your connection.', code);
        break;
      case OtpSendResult.notConfigured:
        _fail(
            'Phone sign-in is not set up for this app build yet. Add the SHA-1 and SHA-256 fingerprints in Firebase and enable the Phone provider.',
            code);
        break;
      case OtpSendResult.unknown:
        _fail('Could not send OTP. Please try again.', code);
        break;
    }
  }

  void _fail(String message, String? code) {
    setState(() {
      _loading = false;
      _errorMessage = context.tr(message);
      _errorCode = code;
    });
  }

  Future<void> _verifyOtp() async {
    if (_loading) return;
    if (_otp.length != 6) {
      setState(() => _errorMessage = context.tr('Enter the full 6-digit OTP'));
      return;
    }

    setState(() {
      _loading = true;
      _errorMessage = null;
      _errorCode = null;
    });

    final result = await _firebase.verifyOtp(_otp);
    if (!mounted) return;

    switch (result) {
      case OtpVerifyResult.success:
        setState(() => _loading = false);
        context.go(AppRoutes.home);
        break;
      case OtpVerifyResult.wrongCode:
        _fail('Incorrect OTP. Please try again.', null);
        break;
      case OtpVerifyResult.expired:
        _fail('OTP expired. Go back and request a new one.', null);
        break;
      case OtpVerifyResult.unknown:
        _fail('Verification failed. Please try again.',
            _firebase.lastOtpErrorCode);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: SingleChildScrollView(
        child: Column(
          children: [
            GradientHeader(
              title: context.tr('Phone Login'),
              subtitle: context.tr('Verify with OTP'),
              showBack: true,
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  if (_errorMessage != null) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _errorMessage!,
                            style: TextStyle(color: Colors.red.shade700),
                          ),
                          if (_errorCode != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Code: $_errorCode',
                              style: TextStyle(
                                  color: Colors.red.shade400, fontSize: 11),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                  if (!_otpSent) ...[
                    Text(
                      context.tr(
                          'Enter your mobile number to receive a one-time password.'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.grey, height: 1.6),
                    ),
                    const SizedBox(height: 32),
                    TextFormField(
                      controller: _phoneCtrl,
                      keyboardType: TextInputType.phone,
                      maxLength: 10,
                      decoration: InputDecoration(
                        labelText: context.tr('Phone Number'),
                        prefixText: '+91 ',
                        prefixIcon: const Icon(Icons.phone),
                        counterText: '',
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _loading ? null : () => _sendOtp(),
                        child: _loading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2))
                            : Text(context.tr('Send OTP')),
                      ),
                    ),
                  ] else ...[
                    Text(
                      '${context.tr('Enter the 6-digit code sent to')}\n+91 ${_phoneCtrl.text.trim()}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.grey, height: 1.6),
                    ),
                    const SizedBox(height: 32),
                    PinCodeTextField(
                      appContext: context,
                      length: 6,
                      animationType: AnimationType.fade,
                      keyboardType: TextInputType.number,
                      pinTheme: PinTheme(
                        shape: PinCodeFieldShape.box,
                        borderRadius: BorderRadius.circular(8),
                        fieldHeight: 50,
                        fieldWidth: 44,
                        activeFillColor: Colors.white,
                        activeColor: AppColors.primary,
                        selectedColor: AppColors.primaryDark,
                        inactiveColor: Colors.grey.shade300,
                      ),
                      onChanged: (v) => _otp = v,
                      onCompleted: (v) {
                        _otp = v;
                        _verifyOtp();
                      },
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _loading ? null : _verifyOtp,
                        child: _loading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2))
                            : Text(context.tr('Verify OTP')),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: (_loading || _resendSeconds > 0)
                          ? null
                          : () => _sendOtp(resend: true),
                      child: Text(_resendSeconds > 0
                          ? '${context.tr('Resend OTP in')} ${_resendSeconds}s'
                          : context.tr('Resend OTP')),
                    ),
                    TextButton(
                      onPressed: () => setState(() {
                        _otpSent = false;
                        _otp = '';
                        _errorMessage = null;
                        _errorCode = null;
                      }),
                      child: Text(context.tr('Change Number')),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
