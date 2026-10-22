import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/session.dart';
import '../theme.dart';

class SignInScreen extends StatelessWidget {
  const SignInScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<Session>();
    final c = AppColors.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ShaderMask(
                  shaderCallback: (r) => AppColors.grad.createShader(r),
                  child: const Icon(Icons.photo_library_rounded, size: 88, color: Colors.white),
                ),
                const SizedBox(height: 16),
                Text('PhotoShare', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: c.text)),
                const SizedBox(height: 8),
                Text('Share your photos privately with friends and family.', textAlign: TextAlign.center, style: TextStyle(color: c.muted, fontSize: 16)),
                const SizedBox(height: 36),
                GradientButton(label: 'Continue with Google', busy: session.signingIn, onPressed: session.signIn),
                if (session.error != null) ...[
                  const SizedBox(height: 16),
                  Text(session.error!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.accent)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
