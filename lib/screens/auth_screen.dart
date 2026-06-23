import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../config/theme.dart';
import '../services/auth_service.dart';
import '../services/data_service.dart';
import 'personalization_setup_screen.dart';
import 'main_shell.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen>
    with SingleTickerProviderStateMixin {
  bool _isSignUp = false;
  bool _isLoading = false;
  bool _obscurePassword = true;

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _animController.dispose();
    super.dispose();
  }

  void _toggleMode() {
    setState(() {
      _isSignUp = !_isSignUp;
      _formKey.currentState?.reset();
    });
  }

  Future<void> _handleEmailAuth() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      if (_isSignUp) {
        await AuthService().signUpWithEmail(
          _emailController.text,
          _passwordController.text,
        );
        if (_nameController.text.trim().isNotEmpty) {
          await DataService().setUserName(_nameController.text.trim());
        }
      } else {
        await AuthService().signInWithEmail(
          _emailController.text,
          _passwordController.text,
        );
      }
      await DataService().setAuthComplete();
      if (mounted) _navigateNext();
    } on FirebaseAuthException catch (e) {
      if (mounted) _showError(AuthService.friendlyError(e));
    } catch (e) {
      if (mounted) _showError('Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoading = true);
    try {
      final result = await AuthService().signInWithGoogle();
      if (result != null) {
        final googleName = result.user?.displayName ?? '';
        if (googleName.isNotEmpty && DataService().userName.isEmpty) {
          await DataService().setUserName(googleName);
        }
        await DataService().setAuthComplete();
        if (mounted) _navigateNext();
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) _showError(AuthService.friendlyError(e));
    } catch (e) {
      if (mounted) _showError('Google Sign-In failed. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleSkip() async {
    await DataService().setAuthSkipped();
    if (mounted) _navigateNext();
  }

  void _navigateNext() {
    final dataService = DataService();
    Widget nextScreen;
    if (!dataService.hasCompletedPersonalization) {
      nextScreen = const PersonalizationSetupScreen();
    } else {
      nextScreen = const MainShell();
    }
    Navigator.of(context).pushAndRemoveUntil(
      PageRouteBuilder(
        pageBuilder: (_, animation, __) => nextScreen,
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
        transitionDuration: const Duration(milliseconds: 500),
      ),
      (route) => false,
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(28, 0, 28, MediaQuery.of(context).viewPadding.bottom + 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 32),

                // ── Header ──
                Center(
                  child: Column(
                    children: [
                      // Logo
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withAlpha(15),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: Image.asset(
                            'assets/images/logo.jpeg',
                            width: 80,
                            height: 80,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        _isSignUp ? 'Create Account' : 'Welcome Back',
                        style: const TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1A1A1A),
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _isSignUp
                            ? 'Sign up to save your progress'
                            : 'Sign in to continue your journey',
                        style: TextStyle(
                          fontSize: 15,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 36),

                // ── Google Sign-In Button ──
                _GoogleSignInButton(
                  isLoading: _isLoading,
                  onPressed: _handleGoogleSignIn,
                ),
                const SizedBox(height: 24),

                // ── Divider ──
                Row(
                  children: [
                    Expanded(child: Divider(color: Colors.grey.shade300)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'or continue with email',
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Expanded(child: Divider(color: Colors.grey.shade300)),
                  ],
                ),
                const SizedBox(height: 24),

                // ── Email & Password Form ──
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      if (_isSignUp) ...[
                        _buildTextField(
                          controller: _nameController,
                          label: 'Name',
                          hint: 'Your name',
                          icon: Icons.person_outline_rounded,
                          textCapitalization: TextCapitalization.words,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter your name';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                      ],
                      _buildTextField(
                        controller: _emailController,
                        label: 'Email',
                        hint: 'you@example.com',
                        icon: Icons.email_outlined,
                        keyboardType: TextInputType.emailAddress,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter your email';
                          }
                          if (!RegExp(r'^[^@]+@[^@]+\.[^@]+')
                              .hasMatch(value.trim())) {
                            return 'Please enter a valid email';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      // Password field
                      _buildTextField(
                        controller: _passwordController,
                        label: 'Password',
                        hint: '••••••••',
                        icon: Icons.lock_outline_rounded,
                        obscure: _obscurePassword,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: Colors.grey.shade500,
                            size: 22,
                          ),
                          onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your password';
                          }
                          if (_isSignUp && value.length < 6) {
                            return 'Password must be at least 6 characters';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),

                // ── Sign In / Sign Up Button ──
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleEmailAuth,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: AppColors.primary.withAlpha(120),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          )
                        : Text(
                            _isSignUp ? 'Create Account' : 'Sign In',
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.3,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 20),

                // ── Toggle Sign In / Sign Up ──
                Center(
                  child: GestureDetector(
                    onTap: _isLoading ? null : _toggleMode,
                    child: RichText(
                      text: TextSpan(
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                        children: [
                          TextSpan(
                            text: _isSignUp
                                ? 'Already have an account? '
                                : "Don't have an account? ",
                          ),
                          TextSpan(
                            text: _isSignUp ? 'Sign In' : 'Sign Up',
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // ── Skip Button ──
                Center(
                  child: TextButton(
                    onPressed: _isLoading ? null : _handleSkip,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 32, vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide(color: Colors.grey.shade300),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.arrow_forward_rounded,
                          color: Colors.grey.shade600,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Skip for now',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // ── Footer hint ──
                Center(
                  child: Text(
                    'You can always sign in later\nfrom Settings',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.grey.shade400,
                      fontSize: 12,
                      height: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool obscure = false,
    Widget? suffixIcon,
    TextInputType keyboardType = TextInputType.text,
    TextCapitalization textCapitalization = TextCapitalization.none,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      validator: validator,
      style: const TextStyle(
        fontSize: 16,
        color: Color(0xFF1A1A1A),
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: TextStyle(
          color: Colors.grey.shade600,
          fontWeight: FontWeight.w500,
        ),
        hintStyle: TextStyle(
          color: Colors.grey.shade400,
          fontWeight: FontWeight.w400,
        ),
        prefixIcon: Icon(icon, color: Colors.grey.shade500, size: 22),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: Colors.grey.shade50,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Google Sign-In Button — styled with official Google branding
// ═══════════════════════════════════════════════════════════════════════

class _GoogleSignInButton extends StatelessWidget {
  final bool isLoading;
  final VoidCallback onPressed;

  const _GoogleSignInButton({
    required this.isLoading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: OutlinedButton(
        onPressed: isLoading ? null : onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white,
          side: BorderSide(color: Colors.grey.shade300, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          minimumSize: const Size.fromHeight(56),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          elevation: 0,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Google "G" icon using a custom painter
            SizedBox(
              width: 24,
              height: 24,
              child: CustomPaint(painter: _GoogleLogoPainter()),
            ),
            const SizedBox(width: 14),
            const Text(
              'Continue with Google',
              style: TextStyle(
                color: Color(0xFF3C4043),
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Google "G" Logo Painter — official 4-color Google logo
// ═══════════════════════════════════════════════════════════════════════

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;

    // Blue
    final bluePaint = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.fill;

    // Red
    final redPaint = Paint()
      ..color = const Color(0xFFEA4335)
      ..style = PaintingStyle.fill;

    // Yellow
    final yellowPaint = Paint()
      ..color = const Color(0xFFFBBC05)
      ..style = PaintingStyle.fill;

    // Green
    final greenPaint = Paint()
      ..color = const Color(0xFF34A853)
      ..style = PaintingStyle.fill;

    final center = Offset(w / 2, h / 2);
    final radius = w / 2;

    // Draw arcs for each color section
    final rect = Rect.fromCircle(center: center, radius: radius);

    // Red - top-right
    canvas.drawArc(rect, -1.1, 0.8, true, redPaint);
    // Yellow - bottom-left
    canvas.drawArc(rect, 2.0, 0.85, true, yellowPaint);
    // Green - bottom-right
    canvas.drawArc(rect, 0.85, 1.15, true, greenPaint);
    // Blue - right side + horizontal bar
    canvas.drawArc(rect, -0.3, 1.15, true, bluePaint);

    // White inner circle to make it a "G" shape
    final innerRect =
        Rect.fromCircle(center: center, radius: radius * 0.55);
    canvas.drawOval(
        innerRect, Paint()..color = Colors.white);

    // Blue bar (horizontal part of "G")
    canvas.drawRect(
      Rect.fromLTWH(w * 0.48, h * 0.38, w * 0.52, h * 0.24),
      bluePaint,
    );

    // White cover on bar top section
    canvas.drawRect(
      Rect.fromLTWH(w * 0.48, h * 0.1, w * 0.52, h * 0.28),
      Paint()..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
