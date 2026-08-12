// lib/views/auth/signup_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/widgets/gradient_scaffold.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../home/home_screen.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _emailController = TextEditingController();
  final _mobileController = TextEditingController();

  Future<void> _handleSignUp(AuthViewModel vm) async {
    if (!_formKey.currentState!.validate()) return;
    final success = await vm.signUp(
      name: _nameController.text.trim(),
      email: _emailController.text.trim(),
      password: _passwordController.text,
      mobile: _mobileController.text.trim(),
    );
    if (success && mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AuthViewModel(),
      child: Consumer<AuthViewModel>(
        builder: (context, vm, _) {
          return GradientScaffold(
            appBar: AppBar(leading: const BackButton()),
            body: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Text(
                      'Sign Up For Our App',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 32),
                    _field(_nameController, 'Name'),
                    const SizedBox(height: 16),
                    _field(_emailController, 'Email', keyboardType: TextInputType.emailAddress),
                    const SizedBox(height: 16),
                    _field(_mobileController, 'Mobile Number', keyboardType: TextInputType.phone),
                    const SizedBox(height: 16),
                    _field(_passwordController, 'Password', obscure: true),
                    const SizedBox(height: 24),
                    if (vm.errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(vm.errorMessage!, style: const TextStyle(color: Colors.red)),
                      ),
                    SizedBox(
                      width: double.infinity,
                      child: vm.isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : ElevatedButton(
                              onPressed: () => _handleSignUp(vm),
                              child: const Text('Sign UP'),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    TextInputType? keyboardType,
    bool obscure = false,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      decoration: InputDecoration(labelText: label),
      validator: (value) => (value == null || value.trim().isEmpty) ? 'Required' : null,
    );
  }
}
