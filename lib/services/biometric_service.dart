import 'package:local_auth/local_auth.dart';

enum BiometricAuthResult {
  success,
  failed,
  unavailable,
  cancelled,
}

class BiometricService {
  final LocalAuthentication _auth =
  LocalAuthentication();

  Future<bool> isAvailable() async {
    try {
      final bool deviceSupported =
      await _auth.isDeviceSupported();

      final bool canCheckBiometrics =
      await _auth.canCheckBiometrics;

      return deviceSupported ||
          canCheckBiometrics;
    } catch (_) {
      return false;
    }
  }

  Future<List<BiometricType>>
  getAvailableBiometrics() async {
    try {
      return await _auth
          .getAvailableBiometrics();
    } catch (_) {
      return <BiometricType>[];
    }
  }

  Future<String>
  getAvailableBiometricLabel() async {
    final List<BiometricType> types =
    await getAvailableBiometrics();

    if (types.isEmpty) {
      final bool supported =
      await isAvailable();

      return supported
          ? 'Device Credential'
          : 'Unavailable';
    }

    final List<String> labels = [];

    void addUnique(String label) {
      if (!labels.contains(label)) {
        labels.add(label);
      }
    }

    for (final BiometricType type in types) {
      switch (type) {
        case BiometricType.face:
          addUnique('Face');
          break;

        case BiometricType.fingerprint:
          addUnique('Fingerprint');
          break;

        case BiometricType.iris:
          addUnique('Iris');
          break;

        case BiometricType.strong:
          addUnique('Strong Biometric');
          break;

        case BiometricType.weak:
          addUnique('Weak Biometric');
          break;
      }
    }

    return labels.isEmpty
        ? 'Device Authentication'
        : labels.join(', ');
  }

  Future<BiometricAuthResult>
  authenticateSecurely({
    required String reason,
    bool biometricOnly = false,
  }) async {
    final bool supported =
    await isAvailable();

    if (!supported) {
      return BiometricAuthResult.unavailable;
    }

    try {
      final bool authenticated =
      await _auth.authenticate(
        localizedReason:
        reason,

        biometricOnly:
        biometricOnly,

        persistAcrossBackgrounding:
        true,
      );

      return authenticated
          ? BiometricAuthResult.success
          : BiometricAuthResult.cancelled;
    } on LocalAuthException {
      return BiometricAuthResult.failed;
    } catch (_) {
      return BiometricAuthResult.failed;
    }
  }

  Future<bool> authenticate({
    String reason =
    'Verify your identity to access SmartCity',
  }) async {
    final result =
    await authenticateSecurely(
      reason: reason,
    );

    return result ==
        BiometricAuthResult.success;
  }

  Future<void> stopAuthentication() async {
    try {
      await _auth.stopAuthentication();
    } catch (_) {}
  }
}