import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _tokenKey = 'access_token';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const JwtDemoApp());
}

class JwtDemoApp extends StatelessWidget {
  const JwtDemoApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'JWT Login Demo',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
          useMaterial3: true,
        ),
        home: const AuthGate(),
      );
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late Future<String?> _token = AuthService.currentValidToken();

  @override
  Widget build(BuildContext context) => FutureBuilder<String?>(
        future: _token,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          return snapshot.data == null
              ? LoginPage(onLoggedIn: _restart)
              : HomePage(token: snapshot.data!, onLoggedOut: _restart);
        },
      );

  void _restart() => setState(() {
        _token = AuthService.currentValidToken();
      });
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, required this.onLoggedIn});
  final VoidCallback onLoggedIn;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController(text: 'demo@example.com');
  final _password = TextEditingController(text: 'password123');
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await AuthService.login(_email.text.trim(), _password.text);
      if (mounted) widget.onLoggedIn();
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Card(
              margin: const EdgeInsets.all(24),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.lock_outline, size: 52, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(height: 16),
                    Text('Welcome back', style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder()),
                      validator: (value) => value != null && value.contains('@') ? null : 'Enter a valid email.',
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _password,
                      obscureText: true,
                      decoration: const InputDecoration(labelText: 'Password', border: OutlineInputBorder()),
                      validator: (value) => value != null && value.length >= 8 ? null : 'Use at least 8 characters.',
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                    ],
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _submitting ? null : _login,
                      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                      child: _submitting
                          ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('Log in'),
                    ),
                    const SizedBox(height: 12),
                    const Text('Demo: demo@example.com / password123', textAlign: TextAlign.center),
                  ]),
                ),
              ),
            ),
          ),
        ),
      );
}

class HomePage extends StatelessWidget {
  const HomePage({super.key, required this.token, required this.onLoggedOut});
  final String token;
  final VoidCallback onLoggedOut;

  @override
  Widget build(BuildContext context) {
    final claims = Jwt.decodePayload(token);
    final expiry = DateTime.fromMillisecondsSinceEpoch((claims['exp'] as int) * 1000).toLocal();
    return Scaffold(
      appBar: AppBar(title: const Text('JWT Login Demo'), actions: [
        TextButton.icon(onPressed: () async { await AuthService.logout(); onLoggedOut(); }, icon: const Icon(Icons.logout), label: const Text('Log out')),
        const SizedBox(width: 8),
      ]),
      body: Center(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.verified_user_outlined, size: 56),
              const SizedBox(height: 16),
              Text('You are signed in', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 16),
              Text('User: ${claims['email']}'),
              Text('Token expires: $expiry'),
              const SizedBox(height: 12),
              const Text('The stored token is checked on each app launch.'),
            ]),
          ),
        ),
      ),
    );
  }
}

class AuthService {
  static Future<void> login(String email, String password) async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
    if (email != 'demo@example.com' || password != 'password123') {
      throw const AuthException('Incorrect email or password.');
    }
    // Replace this with an HTTPS request to your API. The API should return
    // a signed access token after it verifies the credentials.
    final token = Jwt.createDemoToken(email);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  static Future<String?> currentValidToken() async {
    final token = (await SharedPreferences.getInstance()).getString(_tokenKey);
    if (token == null || !Jwt.isUnexpired(token)) {
      await logout();
      return null;
    }
    return token;
  }

  static Future<void> logout() async => (await SharedPreferences.getInstance()).remove(_tokenKey);
}

class AuthException implements Exception {
  const AuthException(this.message);
  final String message;
}

class Jwt {
  static String createDemoToken(String email) {
    String part(Object value) => base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return '${part({'alg': 'none', 'typ': 'JWT'})}.${part({'sub': 'demo-user', 'email': email, 'iat': now, 'exp': now + 3600})}.demo';
  }

  static Map<String, dynamic> decodePayload(String token) {
    try {
      final pieces = token.split('.');
      if (pieces.length != 3) throw const FormatException();
      final normalized = base64Url.normalize(pieces[1]);
      return jsonDecode(utf8.decode(base64Url.decode(normalized))) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  static bool isUnexpired(String token) {
    final exp = decodePayload(token)['exp'];
    return exp is int && DateTime.now().millisecondsSinceEpoch ~/ 1000 < exp;
  }
}
