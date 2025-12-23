import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/login_page.dart';
import '../auth/reset_password_page.dart';
import '../admin/admin_dashboard.dart';
import '../main.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final supabase = Supabase.instance.client;

    return StreamBuilder<AuthState>(
      stream: supabase.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final authState = snapshot.data;
        final session = authState?.session ?? supabase.auth.currentSession;
        final event = authState?.event;

        // 🔁 Deep-link password recovery → show reset screen
        if (event == AuthChangeEvent.passwordRecovery) {
          return const ResetPasswordPage();
        }

        // ❌ Not logged in
        if (session == null) {
          return const LoginPage();
        }

        // ✅ Logged in → load profile (READ ONLY)
        return FutureBuilder<Map<String, dynamic>?>(
          future: _loadProfile(supabase, session.user.id),
          builder: (context, profileSnapshot) {
            if (profileSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            if (profileSnapshot.hasError || !profileSnapshot.hasData) {
              return const Scaffold(
                body: Center(child: Text('Error loading profile')),
              );
            }

            final profile = profileSnapshot.data!;
            final role = profile['role'] as String?;

            // 🔐 Admin
            if (role == 'admin') {
              return const AdminDashboard();
            }

            // 👤 Normal user
            return const MyHomePage(
              title: 'Mental Health Care App',
            );
          },
        );
      },
    );
  }

  /// 🔎 READ profile only — no insert, no update
  Future<Map<String, dynamic>?> _loadProfile(
      SupabaseClient supabase,
      String userId,
      ) async {
    return await supabase
        .from('profiles')
        .select()
        .eq('id', userId)
        .single();
  }
}
