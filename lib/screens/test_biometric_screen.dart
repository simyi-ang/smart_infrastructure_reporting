import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';

import '../services/biometric_service.dart';

class TestBiometricScreen extends StatefulWidget {
  const TestBiometricScreen({super.key});

  @override
  State<TestBiometricScreen> createState() =>
      _TestBiometricScreenState();
}

class _TestBiometricScreenState
    extends State<TestBiometricScreen> {
  final BiometricService _biometricService =
  BiometricService();

  String _status = 'Checking biometric availability...';

  List<BiometricType> _availableBiometrics = [];

  @override
  void initState() {
    super.initState();
    _checkBiometrics();
  }

  String _biometricName(BiometricType type) {
    switch (type) {
      case BiometricType.face:
        return 'Face';

      case BiometricType.fingerprint:
        return 'Fingerprint';

      case BiometricType.iris:
        return 'Iris';

      case BiometricType.strong:
        return 'Strong Biometric';

      case BiometricType.weak:
        return 'Weak Biometric';
    }
  }

  Future<void> _checkBiometrics() async {
    final bool available =
    await _biometricService.isAvailable();

    final List<BiometricType> types =
    await _biometricService
        .getAvailableBiometrics();

    if (!mounted) return;

    setState(() {
      _availableBiometrics = types;

      _status = available
          ? 'Biometric authentication is available.'
          : 'Biometric authentication is not available.';
    });
  }

  Future<void> _authenticate() async {
    final bool success =
    await _biometricService.authenticate(
      reason:
      'Authenticate to test SmartCity biometric security',
    );

    if (!mounted) return;

    setState(() {
      _status = success
          ? 'Authentication successful.'
          : 'Authentication failed or cancelled.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final String biometricText =
    _availableBiometrics.isEmpty
        ? 'None detected'
        : _availableBiometrics
        .map(_biometricName)
        .join(', ');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Biometric Test'),
      ),

      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Column(
            mainAxisAlignment:
            MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.fingerprint,
                size: 90,
              ),

              const SizedBox(height: 24),

              Text(
                _status,
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 16),

              Text(
                'Available biometrics:\n$biometricText',
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 32),

              ElevatedButton.icon(
                onPressed: _authenticate,
                icon: const Icon(
                  Icons.fingerprint,
                ),
                label: const Text(
                  'Test Biometrics',
                ),
              ),

              const SizedBox(height: 12),

              OutlinedButton(
                onPressed: _checkBiometrics,
                child: const Text(
                  'Check Again',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}