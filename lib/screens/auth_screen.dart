import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/auth_service.dart';
import '../services/listening_sync_service.dart';

// ─────────────────────────────────────────────
//  2Block Design Tokens
// ─────────────────────────────────────────────
class _C {
  static const bg = Color(0xFF000000);
  static const v400 = Color(0xFFa78bfa);
  static const v500 = Color(0xFF8b5cf6);
  static const v600 = Color(0xFF7c3aed);
  static const p400 = Color(0xFFc084fc);
  static const p500 = Color(0xFFa855f7);
  static const p600 = Color(0xFF9333ea);
  static const white = Color(0xFFFFFFFF);
  static const gray500 = Color(0xFF737373);

  static const gradMain = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [v400, p400, p500],
    stops: [0.0, 0.5, 1.0],
  );
  static const gradBtn = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [v600, p600],
  );
}

// ─────────────────────────────────────────────
//  AuthScreen
// ─────────────────────────────────────────────
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> with TickerProviderStateMixin {
  final AuthService _authService = AuthService();
  final ListeningSyncService _syncService = ListeningSyncService();
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _passCtrl = TextEditingController();
  bool _isSignUpMode = false;
  bool _isLoading = false;
  bool _obscurePass = true;
  bool _obscureSignUpPass = true;
  bool _nameFocused = false;
  bool _emailFocused = false;
  bool _passFocused = false;
  bool _awaitingEmailConfirmation = false;
  StreamSubscription<AuthState>? _authSub;
  bool _didClose = false;
  Timer? _googleTimeout;

  // Animations
  late final AnimationController _entranceCtrl;
  late final Animation<double> _entranceFade;
  late final Animation<Offset> _entranceSlide;

  late final AnimationController _floatCtrl;
  late final Animation<double> _floatAnim;

  late final AnimationController _loadingCtrl;

  final FocusNode _nameFocus = FocusNode();
  final FocusNode _emailFocus = FocusNode();
  final FocusNode _passFocus = FocusNode();

  @override
  void initState() {
    super.initState();

    // Entrance
    _entranceCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
    _entranceFade =
        CurvedAnimation(parent: _entranceCtrl, curve: Curves.easeOut);
    _entranceSlide =
        Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero).animate(
            CurvedAnimation(parent: _entranceCtrl, curve: Curves.easeOutCubic));
    _entranceCtrl.forward();

    // Float
    _floatCtrl =
        AnimationController(vsync: this, duration: const Duration(seconds: 4))
          ..repeat(reverse: true);
    _floatAnim = Tween<double>(begin: -8, end: 8)
        .animate(CurvedAnimation(parent: _floatCtrl, curve: Curves.easeInOut));

    // Loading spinner
    _loadingCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat();

    // Focus listeners
    _nameFocus
        .addListener(() => setState(() => _nameFocused = _nameFocus.hasFocus));
    _emailFocus.addListener(
        () => setState(() => _emailFocused = _emailFocus.hasFocus));
    _passFocus
        .addListener(() => setState(() => _passFocused = _passFocus.hasFocus));

    // Auth listener
    _authSub = _authService.authStateChanges.listen((state) {
      if (!mounted || _didClose) return;
      final e = state.event;
      if (e == AuthChangeEvent.signedIn ||
          e == AuthChangeEvent.tokenRefreshed) {
        _googleTimeout?.cancel();
        _completeAuthSuccess(
          _awaitingEmailConfirmation
              ? 'Email confirmé. Connexion réussie.'
              : 'Connexion réussie.',
        );
      }
    });
  }

  @override
  void dispose() {
    _googleTimeout?.cancel();
    _authSub?.cancel();
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _nameFocus.dispose();
    _emailFocus.dispose();
    _passFocus.dispose();
    _entranceCtrl.dispose();
    _floatCtrl.dispose();
    _loadingCtrl.dispose();
    super.dispose();
  }

  // ── Actions ───────────────────────────────
  Future<void> _submit() async {
    if (_isSignUpMode) {
      await _submitSignUp();
      return;
    }

    final email = _emailCtrl.text.trim();
    final pass = _passCtrl.text.trim();
    if (email.isEmpty || pass.length < 6) {
      _snack('Email et mot de passe (min 6) requis');
      return;
    }
    if (!await _ensureOnline()) return;
    setState(() => _isLoading = true);
    final err = await _authService.signIn(email: email, password: pass);
    if (!mounted) return;
    setState(() => _isLoading = false);
    if (err != null) {
      _snack(err);
      return;
    }
  }

  Future<void> _submitSignUp() async {
    final name = _nameCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final pass = _passCtrl.text.trim();

    if (name.isEmpty) {
      _snack('Entre ton nom utilisateur');
      return;
    }
    if (email.isEmpty || !email.contains('@')) {
      _snack('Entre une adresse email valide');
      return;
    }

    final passwordError = _validateStrongPassword(pass);
    if (passwordError != null) {
      _snack(passwordError);
      return;
    }

    if (!await _ensureOnline()) return;
    setState(() => _isLoading = true);
    final err = await _authService.signUp(
      email: email,
      password: pass,
      fullName: name,
    );
    if (!mounted) return;
    setState(() => _isLoading = false);
    if (err != null) {
      _snack(err);
      return;
    }

    setState(() {
      _isSignUpMode = false;
      _obscurePass = true;
      _obscureSignUpPass = true;
      _awaitingEmailConfirmation = true;
    });
    _snack(
      'Un mail de confirmation t’a été envoyé. Vérifie ta boîte mail puis clique sur le lien pour revenir automatiquement dans l’application.',
    );
  }

  String? _validateStrongPassword(String password) {
    if (password.length < 8) {
      return 'Le mot de passe doit contenir au moins 8 caractères';
    }
    if (!RegExp(r'[A-Z]').hasMatch(password)) {
      return 'Ajoute au moins une lettre majuscule';
    }
    if (!RegExp(r'[a-z]').hasMatch(password)) {
      return 'Ajoute au moins une lettre minuscule';
    }
    if (!RegExp(r'\d').hasMatch(password)) {
      return 'Ajoute au moins un chiffre';
    }
    if (!RegExp(r'[^A-Za-z0-9]').hasMatch(password)) {
      return 'Ajoute au moins un caractère spécial';
    }
    return null;
  }

  void _toggleMode() {
    setState(() {
      _isSignUpMode = !_isSignUpMode;
      _isLoading = false;
      _obscurePass = true;
      _obscureSignUpPass = true;
    });
  }

  Future<void> _signInGoogle() async {
    if (!await _ensureOnline()) return;
    setState(() => _isLoading = true);
    final err = await _authService.signInWithGoogle();
    if (!mounted) return;
    if (err != null) {
      setState(() => _isLoading = false);
      _snack(err);
      return;
    }
    if (_authService.currentUser != null && !_didClose) {
      _googleTimeout?.cancel();
      _completeAuthSuccess('Connexion réussie.');
      return;
    }
    _snack('Finalise ta connexion Google...');
    _googleTimeout = Timer(const Duration(seconds: 45), () {
      if (!mounted || _didClose) return;
      setState(() => _isLoading = false);
      _snack('Connexion Google annulée. Réessaie.');
    });
  }

  Future<bool> _ensureOnline() async {
    final offline = await _syncService.isCurrentlyOffline();
    if (!mounted) return false;
    if (offline) {
      _snack('Vérifie ta connexion Internet puis réessaie.');
      return false;
    }
    return true;
  }

  void _snack(String msg) {
    final isLightTheme = Theme.of(context).brightness == Brightness.light;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg,
          style: TextStyle(
              color: isLightTheme ? const Color(0xFF1B1F2A) : _C.white,
              fontWeight: FontWeight.w500)),
      backgroundColor: isLightTheme ? Colors.white : const Color(0xFF1a1a2e),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color:
              isLightTheme ? const Color(0xFFE4E8F2) : _C.v500.withOpacity(0.4),
        ),
      ),
      duration: const Duration(seconds: 3),
    ));
  }

  // ─────────────────────────────────────────
  //  BUILD
  // ─────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isLightTheme = Theme.of(context).brightness == Brightness.light;
    return Scaffold(
      backgroundColor: isLightTheme ? const Color(0xFFF8F9FC) : _C.bg,
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          // ── Ambient blobs ──
          _blob(const Offset(-100, -80), 340,
              _C.v600.withOpacity(isLightTheme ? 0.12 : 0.30)),
          _blob(const Offset(160, 420), 280,
              _C.p500.withOpacity(isLightTheme ? 0.10 : 0.18)),
          _blob(const Offset(-80, 560), 260,
              _C.v500.withOpacity(isLightTheme ? 0.08 : 0.14)),

          // ── Rotating ring decoration ──
          Positioned(
            top: -40,
            right: -60,
            child: _RotatingRing(
              size: 220,
              color: _C.v600.withOpacity(isLightTheme ? 0.08 : 0.12),
            ),
          ),
          Positioned(
            bottom: 60,
            left: -80,
            child: _RotatingRing(
                size: 200,
                color: _C.p500.withOpacity(isLightTheme ? 0.07 : 0.10),
                clockwise: false),
          ),

          // ── Content ──
          SafeArea(
            child: FadeTransition(
              opacity: _entranceFade,
              child: SlideTransition(
                position: _entranceSlide,
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                  child: Column(
                    children: [
                      // Logo float animation
                      AnimatedBuilder(
                        animation: _floatAnim,
                        builder: (_, child) => Transform.translate(
                          offset: Offset(0, _floatAnim.value),
                          child: child,
                        ),
                        child: _buildLogo(),
                      ),

                      const SizedBox(height: 40),

                      // Card
                      _buildCard(),

                      const SizedBox(height: 24),

                      // Footer
                      Text(
                        _isSignUpMode
                            ? 'Un mail de confirmation sera envoyé pour finaliser la création du compte.'
                            : 'Connecte-toi à ton compte pour pouvoir télécharger les sons',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: isLightTheme
                              ? const Color(0xFF7A8197)
                              : _C.gray500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────
  //  Logo
  // ─────────────────────────────────────────
  Widget _buildLogo() {
    final isLightTheme = Theme.of(context).brightness == Brightness.light;
    return Column(
      children: [
        // Icon orb
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: _C.gradBtn,
            boxShadow: [
              BoxShadow(
                color: _C.p500.withOpacity(0.5),
                blurRadius: 32,
                spreadRadius: 4,
              ),
            ],
          ),
          child: const Icon(
            Icons.library_music_rounded,
            color: _C.white,
            size: 36,
          ),
        ),
        const SizedBox(height: 18),
        // 2BLOCK title
        ShaderMask(
          shaderCallback: (b) => _C.gradMain.createShader(b),
          child: const Text(
            '2BLOCK',
            style: TextStyle(
              fontSize: 40,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: 0.05,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          _isSignUpMode ? 'Créer ton compte' : 'Connexion à ton compte',
          style: TextStyle(
            fontSize: 14,
            color: isLightTheme ? const Color(0xFF7A8197) : _C.gray500,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────
  //  Card
  // ─────────────────────────────────────────
  Widget _buildCard() {
    final isLightTheme = Theme.of(context).brightness == Brightness.light;
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: isLightTheme
                ? Colors.white.withOpacity(0.92)
                : Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: isLightTheme
                  ? const Color(0xFFE4E8F2)
                  : Colors.white.withOpacity(0.09),
            ),
            boxShadow: [
              BoxShadow(
                color: isLightTheme
                    ? const Color(0x201E2230)
                    : _C.p500.withOpacity(0.1),
                blurRadius: 40,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(22, 28, 22, 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_isSignUpMode) ...[
                _buildField(
                  controller: _nameCtrl,
                  focusNode: _nameFocus,
                  isFocused: _nameFocused,
                  label: 'Nom utilisateur',
                  icon: Icons.person_outline_rounded,
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 14),
              ],
              // Email field
              _buildField(
                controller: _emailCtrl,
                focusNode: _emailFocus,
                isFocused: _emailFocused,
                label: 'Adresse email',
                icon: Icons.alternate_email_rounded,
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 14),

              // Password field
              _buildField(
                controller: _passCtrl,
                focusNode: _passFocus,
                isFocused: _passFocused,
                label: 'Mot de passe',
                icon: Icons.lock_outline_rounded,
                obscure: _isSignUpMode ? _obscureSignUpPass : _obscurePass,
                onChanged: _isSignUpMode ? (_) => setState(() {}) : null,
                suffixIcon: GestureDetector(
                  onTap: () => setState(() {
                    if (_isSignUpMode) {
                      _obscureSignUpPass = !_obscureSignUpPass;
                    } else {
                      _obscurePass = !_obscurePass;
                    }
                  }),
                  child: Icon(
                    (_isSignUpMode ? _obscureSignUpPass : _obscurePass)
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    size: 18,
                    color: _C.gray500,
                  ),
                ),
              ),
              if (_isSignUpMode) ...[
                const SizedBox(height: 12),
                _buildPasswordRules(),
              ],
              const SizedBox(height: 24),

              // Sign in button
              _buildSignInBtn(),

              if (!_isSignUpMode) ...[
                const SizedBox(height: 18),

                // Divider
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 1,
                        color: isLightTheme
                            ? const Color(0xFFE4E8F2)
                            : Colors.white.withOpacity(0.08),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        'ou',
                        style: TextStyle(
                          fontSize: 12,
                          color: isLightTheme
                              ? const Color(0xFF8A90A3)
                              : _C.gray500,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Container(
                        height: 1,
                        color: isLightTheme
                            ? const Color(0xFFE4E8F2)
                            : Colors.white.withOpacity(0.08),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 18),

                // Google button
                _buildGoogleBtn(),
              ],
              const SizedBox(height: 18),
              Center(
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 4,
                  children: [
                    Text(
                      _isSignUpMode ? 'Déjà un compte ?' : 'Pas de compte ?',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: isLightTheme
                            ? const Color(0xFF7A8197)
                            : _C.gray500,
                      ),
                    ),
                    GestureDetector(
                      onTap: _isLoading ? null : _toggleMode,
                      child: Text(
                        _isSignUpMode
                            ? 'Se connecter ici'
                            : 'Créer un compte ici',
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: _C.v500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────
  //  Input Field
  // ─────────────────────────────────────────
  Widget _buildField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required bool isFocused,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    TextCapitalization textCapitalization = TextCapitalization.none,
    ValueChanged<String>? onChanged,
    bool obscure = false,
    Widget? suffixIcon,
  }) {
    final isLightTheme = Theme.of(context).brightness == Brightness.light;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      decoration: BoxDecoration(
        color: isLightTheme
            ? (isFocused ? const Color(0xFFF5F7FC) : const Color(0xFFF8F9FD))
            : Colors.white.withOpacity(isFocused ? 0.07 : 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isFocused
              ? _C.v500.withOpacity(0.6)
              : (isLightTheme
                  ? const Color(0xFFE4E8F2)
                  : Colors.white.withOpacity(0.08)),
          width: isFocused ? 1.5 : 1,
        ),
        boxShadow: isFocused
            ? [
                BoxShadow(
                  color: _C.v500.withOpacity(0.2),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        obscureText: obscure,
        keyboardType: keyboardType,
        textCapitalization: textCapitalization,
        onChanged: onChanged,
        style: TextStyle(
          color: isLightTheme ? const Color(0xFF1B1F2A) : _C.white,
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
        cursorColor: _C.v400,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(
            color: isFocused ? _C.v400 : _C.gray500,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
          prefixIcon:
              Icon(icon, size: 18, color: isFocused ? _C.v400 : _C.gray500),
          suffixIcon: suffixIcon != null
              ? Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: suffixIcon,
                )
              : null,
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
        ),
      ),
    );
  }

  void _completeAuthSuccess(String message) {
    if (_didClose || !mounted) return;
    _didClose = true;
    Navigator.of(context).pop(message);
  }

  Widget _buildPasswordRules() {
    final isLightTheme = Theme.of(context).brightness == Brightness.light;
    final password = _passCtrl.text;
    final rules = <MapEntry<bool, String>>[
      MapEntry(password.length >= 8, '8 caractères minimum'),
      MapEntry(RegExp(r'[A-Z]').hasMatch(password), 'Une majuscule'),
      MapEntry(RegExp(r'[a-z]').hasMatch(password), 'Une minuscule'),
      MapEntry(RegExp(r'\d').hasMatch(password), 'Un chiffre'),
      MapEntry(RegExp(r'[^A-Za-z0-9]').hasMatch(password), 'Un caractère spécial'),
    ];

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isLightTheme
            ? const Color(0xFFF8F9FD)
            : Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isLightTheme
              ? const Color(0xFFE4E8F2)
              : Colors.white.withOpacity(0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Mot de passe robuste',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: isLightTheme ? const Color(0xFF1B1F2A) : _C.white,
            ),
          ),
          const SizedBox(height: 8),
          ...rules.map(
            (rule) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Icon(
                    rule.key
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked_rounded,
                    size: 16,
                    color: rule.key
                        ? const Color(0xFF10B981)
                        : (isLightTheme
                            ? const Color(0xFF8A90A3)
                            : _C.gray500),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    rule.value,
                    style: TextStyle(
                      fontSize: 12,
                      color: isLightTheme
                          ? const Color(0xFF58617A)
                          : _C.gray500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────
  //  Sign In Button
  // ─────────────────────────────────────────
  Widget _buildSignInBtn() {
    final isLightTheme = Theme.of(context).brightness == Brightness.light;
    return GestureDetector(
      onTap: _isLoading ? null : _submit,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 52,
        decoration: BoxDecoration(
          gradient: _isLoading ? null : _C.gradBtn,
          color: _isLoading
              ? (isLightTheme
                  ? const Color(0xFFEFF2FA)
                  : Colors.white.withOpacity(0.06))
              : null,
          borderRadius: BorderRadius.circular(16),
          boxShadow: _isLoading
              ? null
              : [
                  BoxShadow(
                    color: _C.p500.withOpacity(0.4),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ],
        ),
        child: Center(
          child: _isLoading
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    RotationTransition(
                      turns: _loadingCtrl,
                      child: Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _C.v400.withOpacity(0.3),
                            width: 2.5,
                          ),
                        ),
                        child: Align(
                          alignment: Alignment.topCenter,
                          child: Container(
                            width: 4,
                            height: 4,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: _C.v400,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'Traitement…',
                      style: TextStyle(
                        color: _C.gray500,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                  ],
                )
              : Text(
                  _isSignUpMode ? 'Créer le compte' : 'Se connecter',
                  style: TextStyle(
                    color: _C.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    letterSpacing: 0.02,
                  ),
                ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────
  //  Google Button
  // ─────────────────────────────────────────
  Widget _buildGoogleBtn() {
    final isLightTheme = Theme.of(context).brightness == Brightness.light;
    return GestureDetector(
      onTap: _isLoading ? null : _signInGoogle,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: isLightTheme
              ? const Color(0xFFF5F7FC)
              : Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isLightTheme
                ? const Color(0xFFE4E8F2)
                : Colors.white.withOpacity(0.1),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SvgPicture.asset(
              'assets/images/google_g.svg',
              width: 20,
              height: 20,
            ),
            const SizedBox(width: 10),
            Text(
              'Continuer avec Google',
              style: TextStyle(
                color: isLightTheme ? const Color(0xFF1B1F2A) : _C.white,
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────
  //  Blob helper
  // ─────────────────────────────────────────
  Widget _blob(Offset offset, double size, Color color) => Positioned(
        left: offset.dx,
        top: offset.dy,
        child: IgnorePointer(
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
              child: const SizedBox.expand(),
            ),
          ),
        ),
      );
}

// ─────────────────────────────────────────────
//  Rotating Ring Decoration
// ─────────────────────────────────────────────
class _RotatingRing extends StatefulWidget {
  final double size;
  final Color color;
  final bool clockwise;

  const _RotatingRing({
    required this.size,
    required this.color,
    this.clockwise = true,
  });

  @override
  State<_RotatingRing> createState() => _RotatingRingState();
}

class _RotatingRingState extends State<_RotatingRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns:
          widget.clockwise ? _ctrl : Tween(begin: 1.0, end: 0.0).animate(_ctrl),
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: CustomPaint(
          painter: _RingPainter(color: widget.color),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final Color color;
  _RingPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Dashed arc
    const dashCount = 24;
    const gapFraction = 0.4;
    final dashAngle = (2 * math.pi) / dashCount;
    final fillAngle = dashAngle * (1 - gapFraction);

    for (int i = 0; i < dashCount; i++) {
      final startAngle = i * dashAngle;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        fillAngle,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.color != color;
}
