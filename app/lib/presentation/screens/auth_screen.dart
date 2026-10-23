import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../core/theme/anni_theme.dart';
import '../../data/providers/app_providers.dart';
import '../widgets/anni_logo_widget.dart';
import '../widgets/glass_components.dart';

/// Authentication screen supporting Email/Password Sign In, Sign Up,
/// Google Sign-In flow, and Instant Guest Mode.
class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController =
      TextEditingController(text: 'Aria Vance');
  final TextEditingController _emailController =
      TextEditingController(text: 'aria@anni.music');
  final TextEditingController _passwordController =
      TextEditingController(text: 'Obsidian2026!');

  bool _isSignUpMode = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submitAuth() async {
    if (!_formKey.currentState!.validate()) return;
    HapticFeedback.lightImpact();

    final AuthStateNotifier authNotifier = ref.read(authStateProvider.notifier);
    bool success;
    if (_isSignUpMode) {
      success = await authNotifier.register(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        displayName: _nameController.text.trim(),
      );
    } else {
      success = await authNotifier.login(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
    }

    if (!mounted) return;
    if (success) {
      HapticFeedback.mediumImpact();
      context.go('/home');
    }
  }

  Future<void> _handleGoogleSignIn() async {
    HapticFeedback.mediumImpact();
    final bool success = await ref.read(authStateProvider.notifier).loginWithGoogle(
          idToken: 'google_token_${DateTime.now().millisecondsSinceEpoch}',
          email: 'google.listener@anni.music',
          displayName: 'Google Listener',
        );
    if (!mounted) return;
    if (success) {
      context.go('/home');
    }
  }

  void _showForgotPasswordDialog() {
    final TextEditingController emailCtrl = TextEditingController(text: _emailController.text.trim());
    final TextEditingController codeCtrl = TextEditingController();
    final TextEditingController newPassCtrl = TextEditingController();
    int step = 0; // 0 = enter email, 1 = enter code & new pass

    showDialog<void>(
      context: context,
      builder: (BuildContext ctx) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setDialogState) {
          return AlertDialog(
            backgroundColor: AnniTheme.surface1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: Colors.white.withOpacity(0.08)),
            ),
            title: Text(
              step == 0 ? 'Reset Password' : 'Enter Verification Code',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w700,
                color: AnniTheme.textPrimary,
              ),
            ),
            content: step == 0
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Enter your account email to receive a 6-digit reset code.',
                        style: GoogleFonts.plusJakartaSans(color: AnniTheme.textSecondary, fontSize: 13),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        style: GoogleFonts.plusJakartaSans(color: AnniTheme.textPrimary),
                        decoration: InputDecoration(
                          hintText: 'email@anni.music',
                          filled: true,
                          fillColor: AnniTheme.surface2,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ],
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      TextField(
                        controller: codeCtrl,
                        keyboardType: TextInputType.number,
                        style: GoogleFonts.plusJakartaSans(color: AnniTheme.textPrimary),
                        decoration: InputDecoration(
                          hintText: '6-digit code',
                          filled: true,
                          fillColor: AnniTheme.surface2,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: newPassCtrl,
                        obscureText: true,
                        style: GoogleFonts.plusJakartaSans(color: AnniTheme.textPrimary),
                        decoration: InputDecoration(
                          hintText: 'New password (8+ chars)',
                          filled: true,
                          fillColor: AnniTheme.surface2,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ],
                  ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('Cancel', style: GoogleFonts.plusJakartaSans(color: AnniTheme.textSecondary)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AnniTheme.accentViolet,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () async {
                  if (step == 0) {
                    if (emailCtrl.text.contains('@')) {
                      await ref.read(authStateProvider.notifier).forgotPassword(emailCtrl.text.trim());
                      setDialogState(() => step = 1);
                    }
                  } else {
                    final bool res = await ref.read(authStateProvider.notifier).resetPassword(
                          email: emailCtrl.text.trim(),
                          token: codeCtrl.text.trim(),
                          newPassword: newPassCtrl.text,
                        );
                    if (ctx.mounted) Navigator.pop(ctx);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          backgroundColor: AnniTheme.surface2,
                          content: Text(
                            res ? 'Password updated! Please sign in.' : 'Reset failed. Try again.',
                            style: GoogleFonts.plusJakartaSans(color: AnniTheme.textPrimary),
                          ),
                        ),
                      );
                    }
                  }
                },
                child: Text(
                  step == 0 ? 'Send Code' : 'Update Password',
                  style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _continueAsGuest() {
    HapticFeedback.lightImpact();
    context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    final AuthState authState = ref.watch(authStateProvider);

    return Scaffold(
      backgroundColor: AnniTheme.background,
      body: Stack(
        children: <Widget>[
          Positioned(
            top: -100,
            right: -60,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: <Color>[
                    AnniTheme.accentViolet.withOpacity(0.24),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      const AnniLogoWidget(
                        size: 76,
                        animate: true,
                        showWordmark: true,
                        showTagline: true,
                      ),
                      const SizedBox(height: 28),
                      GlassCard(
                        padding: const EdgeInsets.all(22),
                        borderRadius: 24,
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              // Mode switcher tabs
                              Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: AnniTheme.surface2,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Row(
                                  children: <Widget>[
                                    Expanded(
                                      child: _buildModeTab(
                                        title: 'Sign In',
                                        selected: !_isSignUpMode,
                                        onTap: () =>
                                            setState(() => _isSignUpMode = false),
                                      ),
                                    ),
                                    Expanded(
                                      child: _buildModeTab(
                                        title: 'Create Account',
                                        selected: _isSignUpMode,
                                        onTap: () =>
                                            setState(() => _isSignUpMode = true),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 20),

                              if (authState.errorMessage != null) ...<Widget>[
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  margin: const EdgeInsets.only(bottom: 16),
                                  decoration: BoxDecoration(
                                    color: AnniTheme.error.withOpacity(0.14),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: AnniTheme.error.withOpacity(0.45),
                                    ),
                                  ),
                                  child: Row(
                                    children: <Widget>[
                                      const Icon(
                                        LucideIcons.alertCircle,
                                        size: 18,
                                        color: AnniTheme.error,
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          authState.errorMessage!,
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 12.5,
                                            color: AnniTheme.textPrimary,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],

                              if (_isSignUpMode) ...<Widget>[
                                Text(
                                  'Display Name',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    color: AnniTheme.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _nameController,
                                  decoration: const InputDecoration(
                                    hintText: 'Aria Vance',
                                    prefixIcon: Icon(LucideIcons.user, size: 18),
                                  ),
                                  validator: (String? val) {
                                    if (_isSignUpMode &&
                                        (val == null || val.trim().length < 2)) {
                                      return 'Enter a display name (2+ characters)';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 14),
                              ],

                              Text(
                                'Email Address',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: AnniTheme.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 6),
                              TextFormField(
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                decoration: const InputDecoration(
                                  hintText: 'you@anni.music',
                                  prefixIcon: Icon(LucideIcons.mail, size: 18),
                                ),
                                validator: (String? val) {
                                  if (val == null ||
                                      !val.contains('@') ||
                                      !val.contains('.')) {
                                    return 'Enter a valid email address';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 14),

                              Text(
                                'Password',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: AnniTheme.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 6),
                              TextFormField(
                                controller: _passwordController,
                                obscureText: _obscurePassword,
                                decoration: InputDecoration(
                                  hintText: '••••••••',
                                  prefixIcon: const Icon(LucideIcons.lock, size: 18),
                                  suffixIcon: IconButton(
                                    onPressed: () => setState(
                                      () => _obscurePassword = !_obscurePassword,
                                    ),
                                    icon: Icon(
                                      _obscurePassword
                                          ? LucideIcons.eye
                                          : LucideIcons.eyeOff,
                                      size: 18,
                                    ),
                                  ),
                                ),
                                validator: (String? val) {
                                  if (val == null || val.length < 6) {
                                    return 'Password must be at least 6 characters';
                                  }
                                  return null;
                                },
                              ),
                              if (!_isSignUpMode) ...<Widget>[
                                const SizedBox(height: 6),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton(
                                    style: TextButton.styleFrom(
                                      padding: EdgeInsets.zero,
                                      minimumSize: Size.zero,
                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    onPressed: _showForgotPasswordDialog,
                                    child: Text(
                                      'Forgot password?',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 12,
                                        color: AnniTheme.accentViolet,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                              const SizedBox(height: 18),

                              // Primary Gradient Submit Button
                              SizedBox(
                                width: double.infinity,
                                height: 52,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: AnniTheme.primaryGradient,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: ElevatedButton(
                                    onPressed:
                                        authState.isLoading ? null : _submitAuth,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.transparent,
                                      shadowColor: Colors.transparent,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                    ),
                                    child: authState.isLoading
                                        ? const SizedBox(
                                            width: 22,
                                            height: 22,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2.5,
                                              color: Colors.white,
                                            ),
                                          )
                                        : Text(
                                            _isSignUpMode
                                                ? 'Create Cloud Account'
                                                : 'Sign In & Sync Library',
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w700,
                                              color: Colors.white,
                                            ),
                                          ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 14),

                              // Google OAuth Button
                              SizedBox(
                                width: double.infinity,
                                height: 48,
                                child: OutlinedButton.icon(
                                  onPressed: authState.isLoading
                                      ? null
                                      : _handleGoogleSignIn,
                                  icon: const Icon(LucideIcons.chrome, size: 18),
                                  label: Text(
                                    'Continue with Google',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AnniTheme.textPrimary,
                                    side: const BorderSide(
                                      color: AnniTheme.glassBorder,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextButton.icon(
                        onPressed: _continueAsGuest,
                        icon: const Icon(
                          LucideIcons.shieldCheck,
                          size: 16,
                          color: AnniTheme.accentOrange,
                        ),
                        label: Text(
                          'Continue in Offline Guest Mode (No Account Required)',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AnniTheme.textSecondary,
                          ),
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

  Widget _buildModeTab({
    required String title,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          gradient: selected ? AnniTheme.primaryGradient : null,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Center(
          child: Text(
            title,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: selected ? Colors.white : AnniTheme.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
