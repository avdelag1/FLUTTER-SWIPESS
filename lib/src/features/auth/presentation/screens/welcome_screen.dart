import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Brand Wordmark
                    Image.asset(
                      'assets/images/logo.png',
                      width: 280,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(height: 64),
                    
                    // Buttons
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: () {
                          HapticFeedback.mediumImpact();
                          context.push('/auth?mode=login');
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999),
                            side: BorderSide(color: Colors.white.withAlpha(230), width: 2),
                          ),
                          elevation: 0,
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.login_rounded, size: 20),
                            SizedBox(width: 10),
                            Text(
                              'SIGN IN',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: () {
                          HapticFeedback.mediumImpact();
                          context.push('/auth?mode=signup');
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.brandPrimary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999),
                          ),
                          elevation: 0,
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.auto_awesome_rounded, size: 20),
                            SizedBox(width: 10),
                            Text(
                              'CREATE ACCOUNT',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'or swipe logo to enter →',
                      style: TextStyle(
                        color: Colors.white.withAlpha(150),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 3,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            // Footer
            Positioned(
              bottom: 24,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton(
                    onPressed: () {},
                    child: Text(
                      'Terms of Service',
                      style: TextStyle(color: Colors.white.withAlpha(100), fontSize: 12),
                    ),
                  ),
                  Text(
                    '•',
                    style: TextStyle(color: Colors.white.withAlpha(100), fontSize: 12),
                  ),
                  TextButton(
                    onPressed: () {},
                    child: Text(
                      'Privacy Policy',
                      style: TextStyle(color: Colors.white.withAlpha(100), fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
