import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/auth_service.dart';

enum _Step { email, code }

class LoginPopup extends StatefulWidget {
  const LoginPopup({super.key, this.dismissible = true});
  final bool dismissible;

  static Future<void> show(BuildContext context, {bool dismissible = true}) {
    return showGeneralDialog(
      context: context,
      barrierDismissible: dismissible,
      barrierLabel: 'login',
      barrierColor: Colors.black.withValues(alpha: 0.65),
      pageBuilder: (ctx, a, b) => LoginPopup(dismissible: dismissible),
      transitionDuration: const Duration(milliseconds: 220),
      transitionBuilder: (ctx, anim, b, child) {
        return FadeTransition(
          opacity: anim,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.92, end: 1.0)
                .chain(CurveTween(curve: Curves.easeOutCubic))
                .animate(anim),
            child: child,
          ),
        );
      },
    );
  }

  @override
  State<LoginPopup> createState() => _LoginPopupState();
}

class _LoginPopupState extends State<LoginPopup> {
  final _emailCtl = TextEditingController();
  final _codeCtl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  _Step _step = _Step.email;
  bool _busy = false;
  String? _error;
  String? _info;

  @override
  void dispose() {
    _emailCtl.dispose();
    _codeCtl.dispose();
    super.dispose();
  }

  bool _isValidEmail(String s) {
    final v = s.trim();
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v);
  }

  Future<void> _sendCode() async {
    if (!_isValidEmail(_emailCtl.text)) {
      setState(() => _error = 'Enter a valid email');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _info = null;
    });
    try {
      await AuthService.instance.sendLoginCode(_emailCtl.text);
      setState(() {
        _step = _Step.code;
        _info = 'Code sent. Check your inbox.';
      });
    } catch (e) {
      setState(() => _error = _humanError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _verifyCode() async {
    final code = _codeCtl.text.trim();
    if (code.length < 4) {
      setState(() => _error = 'Enter the code from your email');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await AuthService.instance.verifyLoginCode(
        email: _emailCtl.text,
        code: code,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      setState(() => _error = _humanError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _humanError(Object e) {
    final s = e.toString();
    if (s.contains('Invalid login credentials')) return 'Invalid code.';
    if (s.contains('Email rate limit')) return 'Too many tries — wait a minute.';
    if (s.contains('Invalid OTP') || s.contains('token has expired')) {
      return 'Code is wrong or expired.';
    }
    return s.replaceAll('Exception: ', '').replaceAll('AuthException: ', '');
  }

  @override
  Widget build(BuildContext context) {
    // showGeneralDialog gives no Material ancestor, but the TextField below
    // requires one for ink/text rendering. A transparent Material satisfies
    // it without altering the glass look.
    return Material(
      type: MaterialType.transparency,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xE6181233),
                        Color(0xE60E2147),
                        Color(0xE61E3556),
                      ],
                    ),
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.10),
                        width: 1),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
                  child: _form(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _form() {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _header(),
          const SizedBox(height: 14),
          if (_step == _Step.email) ..._emailFields() else ..._codeFields(),
          if (_error != null) ...[
            const SizedBox(height: 10),
            _bar(_error!, const Color(0xFFFF4D5E), Icons.error_outline),
          ],
          if (_info != null && _error == null) ...[
            const SizedBox(height: 10),
            _bar(_info!, const Color(0xFF34C924), Icons.check_circle_outline),
          ],
          const SizedBox(height: 14),
          _primaryButton(),
        ],
      ),
    );
  }

  Widget _header() {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFA63CFF), Color(0xFF1E9BFF)],
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFA63CFF).withValues(alpha: 0.5),
                blurRadius: 16,
              ),
            ],
          ),
          child: const Icon(Icons.shield_moon, color: Colors.white, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Save Your Progress',
                style: GoogleFonts.baloo2(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                ),
              ),
              Text(
                _step == _Step.email
                    ? 'Sign in with email to keep your coins, DNA, XP, level, skins and achievements.'
                    : 'We sent a 6-digit code to ${_emailCtl.text}. Enter it below.',
                style: GoogleFonts.baloo2(
                  color: Colors.white.withValues(alpha: 0.72),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        if (widget.dismissible)
          IconButton(
            onPressed: _busy ? null : () => Navigator.of(context).pop(),
            icon:
                const Icon(Icons.close, color: Colors.white70, size: 20),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
      ],
    );
  }

  List<Widget> _emailFields() {
    return [
      _label('Email'),
      _input(
        controller: _emailCtl,
        hint: 'you@example.com',
        keyboardType: TextInputType.emailAddress,
        autofillHints: const [AutofillHints.email],
      ),
    ];
  }

  List<Widget> _codeFields() {
    return [
      _label('Login Code'),
      _input(
        controller: _codeCtl,
        hint: '6-digit code',
        keyboardType: TextInputType.number,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(6),
        ],
        autofillHints: const [AutofillHints.oneTimeCode],
      ),
      const SizedBox(height: 4),
      TextButton(
        onPressed: _busy
            ? null
            : () => setState(() {
                  _step = _Step.email;
                  _error = null;
                  _info = null;
                  _codeCtl.clear();
                }),
        child: Text(
          'Change email',
          style: GoogleFonts.baloo2(
            color: const Color(0xFF1E9BFF),
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    ];
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 6),
        child: Text(
          text.toUpperCase(),
          style: GoogleFonts.baloo2(
            color: Colors.white60,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
      );

  Widget _input({
    required TextEditingController controller,
    required String hint,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    Iterable<String>? autofillHints,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: Colors.white.withValues(alpha: 0.15), width: 1),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        autofillHints: autofillHints,
        enabled: !_busy,
        style: GoogleFonts.baloo2(
          color: Colors.white,
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
        decoration: InputDecoration(
          isCollapsed: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          hintText: hint,
          hintStyle: GoogleFonts.baloo2(
            color: Colors.white30,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
          border: InputBorder.none,
        ),
      ),
    );
  }

  Widget _bar(String text, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 1),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.baloo2(
                color: Colors.white.withValues(alpha: 0.92),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _primaryButton() {
    final label = _step == _Step.email ? 'SEND LOGIN LINK' : 'VERIFY & SIGN IN';
    return GestureDetector(
      onTap: _busy ? null : (_step == _Step.email ? _sendCode : _verifyCode),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        height: 50,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: _busy
                ? [const Color(0xFF555575), const Color(0xFF6E6E92)]
                : [
                    const Color(0xFFA63CFF),
                    const Color(0xFF1E9BFF),
                    const Color(0xFF00C8E0),
                  ],
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: _busy
              ? []
              : [
                  BoxShadow(
                    color:
                        const Color(0xFF1E9BFF).withValues(alpha: 0.45),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ],
        ),
        alignment: Alignment.center,
        child: _busy
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor:
                      AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Text(
                label,
                style: GoogleFonts.baloo2(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.4,
                ),
              ),
      ),
    );
  }
}
