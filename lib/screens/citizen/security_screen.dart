import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/auth_service.dart';
import '../../services/biometric_service.dart';
import '../../services/quick_lock_service.dart';
import '../../services/security_preferences_service.dart';
import '../../services/security_service.dart';
import '../../services/remembered_account_service.dart';
import '../../theme/app_colors.dart';

import '../auth/auth_gate.dart';
import 'account_activity_screen.dart';

class SecurityScreen extends StatefulWidget {
  const SecurityScreen({
    super.key,
  });

  @override
  State<SecurityScreen> createState() =>
      _SecurityScreenState();
}

class _SecurityScreenState
    extends State<SecurityScreen> {
  final AuthService authService =
  AuthService();

  final BiometricService biometricService =
  BiometricService();

  final SecurityPreferencesService
  securityPreferencesService =
  SecurityPreferencesService();

  final SecurityService securityService =
  SecurityService();

  final QuickLockService quickLockService =
  QuickLockService();

  final RememberedAccountService
  rememberedAccountService =
  RememberedAccountService();

  bool biometricSupported = false;

  bool biometricEnabled = false;

  bool quickLoginEnabled = false;

  bool biometricLoading = true;

  int autoLockSeconds = 60;

  String biometricCapability =
      'Checking...';

  final GlobalKey<FormState>
  passwordFormKey =
  GlobalKey<FormState>();

  final TextEditingController
  currentPasswordController =
  TextEditingController();

  final TextEditingController
  newPasswordController =
  TextEditingController();

  final TextEditingController
  confirmPasswordController =
  TextEditingController();

  bool loading = false;

  bool hideCurrentPassword = true;

  bool hideNewPassword = true;

  bool hideConfirmPassword = true;

  late Map<String, String> sessionInfo;

  // ============================================================
  // INITIALIZATION
  // ============================================================

  @override
  void initState() {
    super.initState();

    sessionInfo =
        authService.getSessionInfo();

    _loadSecuritySettings();
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    currentPasswordController.dispose();

    newPasswordController.dispose();

    confirmPasswordController.dispose();

    super.dispose();
  }

  // ============================================================
  // SIGN OUT
  //
  // IMPORTANT:
  //
  // This is the normal SmartCity Sign Out.
  //
  // When Quick Login is enabled:
  // - current Supabase session remains
  // - Login screen opens
  // - Quick Login / Email / Google are available
  //
  // It is therefore a trusted-device sign out.
  //
  // "Forget This Device" performs the full logout.
  // ============================================================

  Future<void> logout() async {
    if (!quickLoginEnabled) {
      // Without Quick Login there is no reason to preserve
      // a trusted session. Perform a real logout.
      try {
        await securityService
            .logActivity(
          'SIGN_OUT',
          'The user signed out of SmartCity.',
        );

        await quickLockService
            .clearForFullSignOut();

        await authService.logout();

        if (!mounted) {
          return;
        }

        Navigator.of(context)
            .pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) =>
            const AuthGate(),
          ),
              (route) => false,
        );
      } catch (e) {
        if (!mounted) {
          return;
        }

        showMessage(
          e.toString().replaceFirst(
            'Exception: ',
            '',
          ),
        );
      }

      return;
    }

    // Quick Login is enabled.
    // Return to login while retaining trusted session.
    try {
      await quickLockService
          .lockForReturnToLogin();

      await securityService
          .logActivity(
        'SIGN_OUT',
        'The user returned to Login while preserving trusted-device Quick Login.',
      );

      if (!mounted) {
        return;
      }

      Navigator.of(context)
          .pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) =>
          const AuthGate(),
        ),
            (route) => false,
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      showMessage(
        'Unable to sign out.',
      );
    }
  }

  // ============================================================
  // FORGET THIS DEVICE
  //
  // STRONGEST LOGOUT ACTION
  //
  // Removes:
  // - remembered email
  // - remembered Google identity
  // - Quick Login
  // - Quick Lock
  // - current trusted-device verification
  //
  // Then performs a REAL Supabase logout.
  // ============================================================

  Future<void> forgetThisDevice() async {
    final bool? confirmed =
    await showDialog<bool>(
      context:
      context,

      builder:
          (dialogContext) {
        return AlertDialog(
          backgroundColor:
          AppColors.surface,

          title:
          const Text(
            'Forget This Device?',
          ),

          content:
          const Text(
            'This will remove Quick Login and remembered account information from this device, end your current session, and require normal sign-in next time.',
          ),

          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  false,
                );
              },

              child:
              const Text(
                'Cancel',
              ),
            ),

            ElevatedButton(
              style:
              ElevatedButton.styleFrom(
                backgroundColor:
                AppColors.danger,
              ),

              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  true,
                );
              },

              child:
              const Text(
                'Forget Device',
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    setState(() {
      loading = true;
    });

    try {
      await securityService
          .logActivity(
        'DEVICE_FORGOTTEN',
        'Quick Login and remembered account information were removed from this device.',
      );

      // Remove remembered Email / Google identity.
      await rememberedAccountService
          .forgetDevice();

      // Disable Quick Login remotely first while
      // the authenticated user still exists.
      await securityService
          .setQuickLoginEnabled(
        false,
      );

      // Disable Quick Login locally.
      await quickLockService
          .setQuickLoginEnabled(
        false,
      );

      // Clear local trusted lock state.
      await quickLockService
          .clearForFullSignOut();

      // Real logout.
      await authService.logout();

      if (!mounted) {
        return;
      }

      Navigator.of(context)
          .pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) =>
          const AuthGate(),
        ),
            (route) => false,
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      showMessage(
        e.toString().replaceFirst(
          'Exception: ',
          '',
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  // ============================================================
  // QUICK LOGIN ENABLE / DISABLE
  // ============================================================

  Future<void> _toggleQuickLogin(
      bool value,
      ) async {
    if (biometricLoading) {
      return;
    }

    if (!biometricSupported) {
      showMessage(
        'Device authentication is not available on this device.',
      );

      return;
    }

    setState(() {
      biometricLoading = true;
    });

    try {
      final BiometricAuthResult result =
      await biometricService
          .authenticateSecurely(
        reason:
        value
            ? 'Verify your identity to enable Quick Login'
            : 'Verify your identity to disable Quick Login',
      );

      switch (result) {
        case BiometricAuthResult.success:
          break;

        case BiometricAuthResult.cancelled:
          showMessage(
            'Quick Login verification was cancelled.',
          );
          return;

        case BiometricAuthResult.unavailable:
          showMessage(
            'Device authentication is unavailable.',
          );
          return;

        case BiometricAuthResult.failed:
          showMessage(
            'Identity verification was unsuccessful.',
          );
          return;
      }

      await quickLockService
          .setQuickLoginEnabled(
        value,
      );

      await securityService
          .setQuickLoginEnabled(
        value,
      );

      if (!value) {
        await quickLockService
            .clearQuickLockState();

        quickLockService
            .requireVerificationAgain();
      } else {
        // The user just verified identity while enabling
        // Quick Login. Do not immediately lock this run.
        quickLockService
            .markVerifiedForCurrentRun();
      }

      if (!mounted) {
        return;
      }

      setState(() {
        quickLoginEnabled =
            value;
      });

      showMessage(
        value
            ? 'Quick Login enabled.'
            : 'Quick Login disabled.',
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      showMessage(
        'Unable to update Quick Login.',
      );
    } finally {
      if (mounted) {
        setState(() {
          biometricLoading =
          false;
        });
      }
    }
  }

  // ============================================================
  // QUICK LOCK
  // ============================================================

  Future<void> quickLock() async {
    if (!quickLoginEnabled) {
      showMessage(
        'Enable Quick Login before using Quick Lock.',
      );

      return;
    }

    if (!biometricSupported) {
      showMessage(
        'Device authentication is unavailable.',
      );

      return;
    }

    try {
      await quickLockService
          .manualQuickLock();

      await securityService
          .logActivity(
        'QUICK_LOCK',
        'SmartCity was manually locked for Quick Login.',
      );

      if (!mounted) {
        return;
      }

      Navigator.of(context)
          .pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) =>
          const AuthGate(),
        ),
            (route) => false,
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      showMessage(
        'Unable to lock SmartCity.',
      );
    }
  }

  // ============================================================
  // LOAD SECURITY SETTINGS
  // ============================================================

  Future<void>
  _loadSecuritySettings() async {
    try {
      final bool supported =
      await biometricService
          .isAvailable();

      final String capability =
      await biometricService
          .getAvailableBiometricLabel();

      await securityService
          .ensureSecuritySettings();

      final Map<String, dynamic>?
      remoteSettings =
      await securityService
          .getSecuritySettings();

      final bool localEnabled =
      await securityPreferencesService
          .isBiometricLockEnabled();

      final int localAutoLock =
      await securityPreferencesService
          .getAutoLockSeconds();

      final bool localQuickLogin =
      await quickLockService
          .isQuickLoginEnabled();

      bool enabled =
          localEnabled;

      int lockSeconds =
          localAutoLock;

      bool quickEnabled =
          localQuickLogin;

      if (remoteSettings != null) {
        enabled =
            remoteSettings[
            'biometric_lock_enabled']
            as bool? ??
                localEnabled;

        lockSeconds =
            remoteSettings[
            'auto_lock_seconds']
            as int? ??
                localAutoLock;

        quickEnabled =
            remoteSettings[
            'quick_login_enabled']
            as bool? ??
                localQuickLogin;

        await securityPreferencesService
            .setBiometricLockEnabled(
          enabled,
        );

        await securityPreferencesService
            .setAutoLockSeconds(
          lockSeconds,
        );

        await quickLockService
            .setQuickLoginEnabled(
          quickEnabled,
        );
      }

      if (!mounted) {
        return;
      }

      setState(() {
        biometricSupported =
            supported;

        biometricEnabled =
            supported &&
                enabled;

        quickLoginEnabled =
            supported &&
                quickEnabled;

        autoLockSeconds =
            lockSeconds;

        biometricCapability =
            capability;

        biometricLoading =
        false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        biometricLoading =
        false;

        biometricCapability =
        'Unable to detect';
      });

      showMessage(
        'Unable to load biometric security settings.',
      );
    }
  }

  // ============================================================
  // SENSITIVE ACTION RE-AUTHENTICATION
  // ============================================================

  Future<bool> _verifySensitiveAction({
    required String reason,
  }) async {
    if (!biometricEnabled) {
      return true;
    }

    final BiometricAuthResult result =
    await biometricService
        .authenticateSecurely(
      reason:
      reason,
    );

    switch (result) {
      case BiometricAuthResult.success:
        await securityService
            .logActivity(
          'SECURITY_REAUTH_SUCCESS',
          'Sensitive action identity verification succeeded.',
        );
        return true;

      case BiometricAuthResult.unavailable:
        showMessage(
          'Device authentication is currently unavailable.',
        );
        return false;

      case BiometricAuthResult.cancelled:
        await securityService
            .logActivity(
          'SECURITY_REAUTH_CANCELLED',
          'Sensitive action identity verification was cancelled.',
        );

        showMessage(
          'Identity verification was cancelled.',
        );
        return false;

      case BiometricAuthResult.failed:
        await securityService
            .logActivity(
          'SECURITY_REAUTH_FAILED',
          'Sensitive action identity verification was unsuccessful.',
        );

        showMessage(
          'Identity verification was unsuccessful.',
        );
        return false;
    }
  }

  // ============================================================
  // BIOMETRIC APP LOCK
  // ============================================================

  Future<void> _toggleBiometric(
      bool value,
      ) async {
    if (biometricLoading) {
      return;
    }

    if (!biometricSupported) {
      showMessage(
        'Biometric authentication is not available on this device.',
      );
      return;
    }

    setState(() {
      biometricLoading =
      true;
    });

    try {
      final BiometricAuthResult result =
      await biometricService
          .authenticateSecurely(
        reason:
        value
            ? 'Verify your identity to enable biometric app lock'
            : 'Verify your identity to disable biometric app lock',
      );

      if (result !=
          BiometricAuthResult.success) {
        if (!mounted) {
          return;
        }

        showMessage(
          result ==
              BiometricAuthResult
                  .unavailable
              ? 'Device authentication is unavailable.'
              : 'Identity verification was cancelled or unsuccessful.',
        );

        return;
      }

      await securityPreferencesService
          .setBiometricLockEnabled(
        value,
      );

      await securityService
          .setBiometricEnabled(
        value,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        biometricEnabled =
            value;
      });

      showMessage(
        value
            ? 'Biometric app lock enabled.'
            : 'Biometric app lock disabled.',
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      showMessage(
        'Unable to update biometric app lock.',
      );
    } finally {
      if (mounted) {
        setState(() {
          biometricLoading =
          false;
        });
      }
    }
  }

  // ============================================================
  // AUTO LOCK
  // ============================================================

  Future<void> _changeAutoLock(
      int seconds,
      ) async {
    if (!biometricEnabled) {
      return;
    }

    final bool verified =
    await _verifySensitiveAction(
      reason:
      'Verify your identity before changing SmartCity auto-lock settings',
    );

    if (!verified) {
      return;
    }

    try {
      String label;

      switch (seconds) {
        case 0:
          label =
          'Immediately';
          break;

        case 60:
          label =
          'After 1 minute';
          break;

        case 300:
          label =
          'After 5 minutes';
          break;

        default:
          showMessage(
            'Unsupported auto-lock duration.',
          );
          return;
      }

      await securityPreferencesService
          .setAutoLockSeconds(
        seconds,
      );

      await securityService
          .setAutoLockSeconds(
        seconds,
      );

      await securityService
          .logActivity(
        'AUTO_LOCK_CHANGED',
        'Automatic app lock was changed to $label.',
      );

      if (!mounted) {
        return;
      }

      setState(() {
        autoLockSeconds =
            seconds;
      });

      showMessage(
        'Auto-lock changed to $label.',
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      showMessage(
        'Unable to update auto-lock settings.',
      );
    }
  }

  // ============================================================
  // CHANGE PASSWORD
  // ============================================================

  Future<void> changePassword() async {
    if (!(passwordFormKey.currentState
        ?.validate() ??
        false)) {
      return;
    }

    final bool verified =
    await _verifySensitiveAction(
      reason:
      'Verify your identity before changing your SmartCity password',
    );

    if (!verified) {
      return;
    }

    final String currentPassword =
        currentPasswordController.text;

    final String newPassword =
        newPasswordController.text;

    if (currentPassword ==
        newPassword) {
      showMessage(
        'New password must be different from your current password.',
      );
      return;
    }

    setState(() {
      loading = true;
    });

    try {
      await authService
          .changePasswordWithCurrentPassword(
        currentPassword:
        currentPassword,

        newPassword:
        newPassword,
      );

      // ========================================================
      // PASSWORD MANAGER UPDATE
      //
      // SmartCity NEVER stores the raw password.
      //
      // This asks the operating system credential manager
      // to save/update the credential.
      // ========================================================

      TextInput.finishAutofillContext(
        shouldSave: true,
      );

      await securityService
          .logActivity(
        'PASSWORD_CHANGED',
        'The account password was changed successfully.',
      );

      if (!mounted) {
        return;
      }

      currentPasswordController.clear();

      newPasswordController.clear();

      confirmPasswordController.clear();

      showMessage(
        'Password changed successfully. '
            'Your device password manager may ask to update the saved password.',
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      showMessage(
        e.toString().replaceFirst(
          'Exception: ',
          '',
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  // ============================================================
  // DELETE ACCOUNT
  // ============================================================

  Future<void>
  requestAccountDeletion() async {
    final bool verified =
    await _verifySensitiveAction(
      reason:
      'Verify your identity before requesting SmartCity account deletion',
    );

    if (!verified) {
      return;
    }

    if (authService
        .hasEmailPasswordIdentity) {
      await _passwordDeletionDialog();
      return;
    }

    if (authService.isGoogleUser) {
      await _googleDeletionDialog();
      return;
    }

    showMessage(
      'Unable to determine your sign-in method.',
    );
  }

  Future<void>
  _passwordDeletionDialog() async {
    final TextEditingController
    passwordController =
    TextEditingController();

    bool obscure = true;

    final String? password =
    await showDialog<String>(
      context:
      context,

      barrierDismissible:
      false,

      builder:
          (dialogContext) {
        return StatefulBuilder(
          builder:
              (
              context,
              setDialogState,
              ) {
            return AlertDialog(
              backgroundColor:
              AppColors.surface,

              title:
              const Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color:
                    AppColors.danger,
                  ),
                  SizedBox(
                    width:
                    10,
                  ),
                  Expanded(
                    child:
                    Text(
                      'Confirm Account Deletion',
                    ),
                  ),
                ],
              ),

              content:
              Column(
                mainAxisSize:
                MainAxisSize.min,

                crossAxisAlignment:
                CrossAxisAlignment.start,

                children: [
                  const Text(
                    'For security, enter your current password before requesting account deletion.',
                  ),

                  const SizedBox(
                    height:
                    18,
                  ),

                  TextField(
                    controller:
                    passwordController,

                    obscureText:
                    obscure,

                    autofocus:
                    true,

                    decoration:
                    _securityInput(
                      hint:
                      'Current password',

                      icon:
                      Icons.lock_outline,

                      suffix:
                      IconButton(
                        onPressed: () {
                          setDialogState(() {
                            obscure =
                            !obscure;
                          });
                        },

                        icon:
                        Icon(
                          obscure
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(
                    height:
                    12,
                  ),

                  const Text(
                    'Your account will first be marked as pending deletion. This request can then be reviewed before permanent removal.',
                    style:
                    TextStyle(
                      color:
                      AppColors.textSecondary,
                      fontSize:
                      10,
                      height:
                      1.4,
                    ),
                  ),
                ],
              ),

              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(
                      dialogContext,
                    );
                  },

                  child:
                  const Text(
                    'Cancel',
                  ),
                ),

                ElevatedButton(
                  style:
                  ElevatedButton.styleFrom(
                    backgroundColor:
                    AppColors.danger,
                  ),

                  onPressed: () {
                    final String value =
                        passwordController.text;

                    if (value.isEmpty) {
                      return;
                    }

                    Navigator.pop(
                      dialogContext,
                      value,
                    );
                  },

                  child:
                  const Text(
                    'Continue',
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    passwordController.dispose();

    if (password == null ||
        password.isEmpty) {
      return;
    }

    final bool? finalConfirmation =
    await _finalDeletionConfirmation();

    if (finalConfirmation != true) {
      return;
    }

    setState(() {
      loading = true;
    });

    try {
      await authService
          .requestAccountDeletionAfterPassword(
        currentPassword:
        password,
      );

      if (!mounted) {
        return;
      }

      Navigator.of(context)
          .pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) =>
          const AuthGate(),
        ),
            (route) => false,
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      showMessage(
        e.toString().replaceFirst(
          'Exception: ',
          '',
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  Future<void>
  _googleDeletionDialog() async {
    final bool? reauth =
    await showDialog<bool>(
      context:
      context,

      builder:
          (dialogContext) {
        return AlertDialog(
          backgroundColor:
          AppColors.surface,

          title:
          const Row(
            children: [
              Icon(
                Icons.security,
                color:
                AppColors.primary,
              ),
              SizedBox(
                width:
                10,
              ),
              Expanded(
                child:
                Text(
                  'Verify Google Account',
                ),
              ),
            ],
          ),

          content:
          const Text(
            'For security, Google Sign-In will open again to verify your identity before the deletion request is submitted.',
          ),

          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  false,
                );
              },

              child:
              const Text(
                'Cancel',
              ),
            ),

            ElevatedButton(
              style:
              ElevatedButton.styleFrom(
                backgroundColor:
                AppColors.primaryDark,
              ),

              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  true,
                );
              },

              child:
              const Text(
                'Verify with Google',
              ),
            ),
          ],
        );
      },
    );

    if (reauth != true) {
      return;
    }

    final bool? finalConfirmation =
    await _finalDeletionConfirmation();

    if (finalConfirmation != true) {
      return;
    }

    setState(() {
      loading = true;
    });

    try {
      await authService
          .requestAccountDeletionAfterGoogle();

      if (!mounted) {
        return;
      }

      Navigator.of(context)
          .pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) =>
          const AuthGate(),
        ),
            (route) => false,
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      showMessage(
        e.toString().replaceFirst(
          'Exception: ',
          '',
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  Future<bool?>
  _finalDeletionConfirmation() {
    return showDialog<bool>(
      context:
      context,

      builder:
          (dialogContext) {
        return AlertDialog(
          backgroundColor:
          AppColors.surface,

          title:
          const Text(
            'Are you sure?',
          ),

          content:
          const Text(
            'This will submit an account deletion request and sign you out.',
          ),

          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  false,
                );
              },

              child:
              const Text(
                'No, Keep Account',
              ),
            ),

            ElevatedButton(
              style:
              ElevatedButton.styleFrom(
                backgroundColor:
                AppColors.danger,
              ),

              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  true,
                );
              },

              child:
              const Text(
                'Yes, Request Deletion',
              ),
            ),
          ],
        );
      },
    );
  }

  // ============================================================
  // ACTIVITY
  // ============================================================

  void openActivity() {
    Navigator.push(
      context,

      MaterialPageRoute(
        builder: (_) =>
        const AccountActivityScreen(),
      ),
    );
  }

  // ============================================================
  // MESSAGE
  // ============================================================

  void showMessage(
      String message,
      ) {
    ScaffoldMessenger.of(context)
        .hideCurrentSnackBar();

    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content:
        Text(
          message,
        ),
      ),
    );
  }

  // ============================================================
  // PASSWORD VALIDATION
  // ============================================================

  String? validatePassword(
      String? value,
      ) {
    final String password =
        value ?? '';

    if (password.isEmpty) {
      return 'Password is required.';
    }

    if (password.length < 8) {
      return 'Use at least 8 characters.';
    }

    if (!RegExp(
      r'[A-Z]',
    ).hasMatch(password)) {
      return 'Add at least one uppercase letter.';
    }

    if (!RegExp(
      r'[a-z]',
    ).hasMatch(password)) {
      return 'Add at least one lowercase letter.';
    }

    if (!RegExp(
      r'[0-9]',
    ).hasMatch(password)) {
      return 'Add at least one number.';
    }

    if (!RegExp(
      r'[!@#$%^&*(),.?":{}|<>]',
    ).hasMatch(password)) {
      return 'Add at least one special character.';
    }

    return null;
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(
      BuildContext context,
      ) {
    final bool emailVerified =
        authService.isEmailVerified;

    final bool googleUser =
        authService.isGoogleUser;

    final bool emailPasswordUser =
        authService
            .hasEmailPasswordIdentity;

    return Scaffold(
      backgroundColor:
      AppColors.background,

      body:
      SafeArea(
        child:
        ListView(
          padding:
          const EdgeInsets.all(
            18,
          ),

          children: [
            // ================================================
            // HEADER
            // ================================================

            Row(
              children: [
                Container(
                  decoration:
                  BoxDecoration(
                    color:
                    AppColors.surface,

                    borderRadius:
                    BorderRadius.circular(
                      12,
                    ),

                    border:
                    Border.all(
                      color:
                      AppColors.border,
                    ),
                  ),

                  child:
                  IconButton(
                    onPressed:
                    loading
                        ? null
                        : () {
                      Navigator.pop(
                        context,
                      );
                    },

                    icon:
                    const Icon(
                      Icons.arrow_back,
                    ),
                  ),
                ),

                const SizedBox(
                  width:
                  12,
                ),

                const Expanded(
                  child:
                  Column(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,

                    children: [
                      Text(
                        'Security',
                        style:
                        TextStyle(
                          fontSize:
                          23,
                          fontWeight:
                          FontWeight.bold,
                        ),
                      ),

                      Text(
                        'Protect your SmartCity account',
                        style:
                        TextStyle(
                          color:
                          AppColors.textSecondary,
                          fontSize:
                          11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(
              height:
              20,
            ),

            // ================================================
            // ACCOUNT SECURITY
            // ================================================

            _SecurityCard(
              title:
              'Account Security',

              children: [
                _SecurityInfoRow(
                  icon:
                  Icons.email_outlined,
                  title:
                  'Email Verification',
                  value:
                  emailVerified
                      ? 'Verified'
                      : 'Not Verified',
                  valueColor:
                  emailVerified
                      ? AppColors.success
                      : AppColors.warning,
                ),

                _SecurityInfoRow(
                  icon:
                  Icons.login,
                  title:
                  'Sign-In Method',
                  value:
                  authService.signInMethod,
                ),

                _SecurityInfoRow(
                  icon:
                  Icons.account_circle_outlined,
                  title:
                  'Google Account',
                  value:
                  googleUser
                      ? 'Connected'
                      : 'Not Connected',
                ),

                _SecurityInfoRow(
                  icon:
                  Icons.shield_outlined,
                  title:
                  'Session',
                  value:
                  authService.currentSession !=
                      null
                      ? 'Active'
                      : 'Inactive',
                  valueColor:
                  authService.currentSession !=
                      null
                      ? AppColors.success
                      : AppColors.warning,
                ),
              ],
            ),

            const SizedBox(
              height:
              16,
            ),

            // ================================================
            // BIOMETRIC & APP LOCK
            // ================================================

            _SecurityCard(
              title:
              'Biometric & App Lock',

              children: [
                SwitchListTile(
                  contentPadding:
                  EdgeInsets.zero,

                  secondary:
                  Icon(
                    Icons.fingerprint,
                    color:
                    biometricSupported
                        ? AppColors.primary
                        : AppColors.textSecondary,
                  ),

                  title:
                  const Text(
                    'Biometric App Lock',
                    style:
                    TextStyle(
                      fontSize:
                      12,
                      fontWeight:
                      FontWeight.bold,
                    ),
                  ),

                  subtitle:
                  Text(
                    biometricSupported
                        ? 'Protect your active session using fingerprint, face, or device credentials supported by this device.'
                        : 'Biometric authentication is unavailable on this device.',
                    style:
                    const TextStyle(
                      color:
                      AppColors.textSecondary,
                      fontSize:
                      9,
                      height:
                      1.4,
                    ),
                  ),

                  value:
                  biometricEnabled,

                  onChanged:
                  biometricLoading ||
                      !biometricSupported
                      ? null
                      : _toggleBiometric,
                ),

                const Divider(
                  color:
                  AppColors.border,
                ),

                _SecurityInfoRow(
                  icon:
                  Icons.verified_user_outlined,
                  title:
                  'Device Authentication',
                  value:
                  biometricSupported
                      ? 'Available'
                      : 'Unavailable',
                  valueColor:
                  biometricSupported
                      ? AppColors.success
                      : AppColors.warning,
                ),

                const Divider(
                  color:
                  AppColors.border,
                ),

                SwitchListTile(
                  contentPadding:
                  EdgeInsets.zero,

                  secondary:
                  Icon(
                    Icons.login_outlined,
                    color:
                    biometricSupported
                        ? AppColors.primary
                        : AppColors.textSecondary,
                  ),

                  title:
                  const Text(
                    'Quick Login',
                    style:
                    TextStyle(
                      fontSize:
                      12,
                      fontWeight:
                      FontWeight.bold,
                    ),
                  ),

                  subtitle:
                  Text(
                    biometricSupported
                        ? 'Use fingerprint, supported face authentication, or device PIN after Sign Out, Quick Lock, or when reopening SmartCity with an active trusted session.'
                        : 'Quick Login is unavailable because device authentication is not supported.',
                    style:
                    const TextStyle(
                      color:
                      AppColors.textSecondary,
                      fontSize:
                      9,
                      height:
                      1.4,
                    ),
                  ),

                  value:
                  quickLoginEnabled,

                  onChanged:
                  biometricLoading ||
                      !biometricSupported
                      ? null
                      : _toggleQuickLogin,
                ),

                _SecurityInfoRow(
                  icon:
                  Icons.security_outlined,
                  title:
                  'Authentication Methods',
                  value:
                  biometricCapability,
                  valueColor:
                  biometricSupported
                      ? AppColors.success
                      : AppColors.warning,
                ),

                if (biometricEnabled) ...[
                  const Divider(
                    color:
                    AppColors.border,
                  ),

                  const Padding(
                    padding:
                    EdgeInsets.only(
                      top:
                      8,
                      bottom:
                      6,
                    ),
                    child:
                    Text(
                      'Automatically Lock',
                      style:
                      TextStyle(
                        fontSize:
                        11,
                        fontWeight:
                        FontWeight.bold,
                      ),
                    ),
                  ),

                  RadioListTile<int>(
                    contentPadding:
                    EdgeInsets.zero,
                    dense:
                    true,
                    title:
                    const Text(
                      'Immediately',
                    ),
                    value:
                    0,
                    groupValue:
                    autoLockSeconds,
                    onChanged:
                    biometricLoading
                        ? null
                        : (value) {
                      if (value != null) {
                        _changeAutoLock(
                          value,
                        );
                      }
                    },
                  ),

                  RadioListTile<int>(
                    contentPadding:
                    EdgeInsets.zero,
                    dense:
                    true,
                    title:
                    const Text(
                      'After 1 minute',
                    ),
                    value:
                    60,
                    groupValue:
                    autoLockSeconds,
                    onChanged:
                    biometricLoading
                        ? null
                        : (value) {
                      if (value != null) {
                        _changeAutoLock(
                          value,
                        );
                      }
                    },
                  ),

                  RadioListTile<int>(
                    contentPadding:
                    EdgeInsets.zero,
                    dense:
                    true,
                    title:
                    const Text(
                      'After 5 minutes',
                    ),
                    value:
                    300,
                    groupValue:
                    autoLockSeconds,
                    onChanged:
                    biometricLoading
                        ? null
                        : (value) {
                      if (value != null) {
                        _changeAutoLock(
                          value,
                        );
                      }
                    },
                  ),
                ],

                if (biometricLoading)
                  const Padding(
                    padding:
                    EdgeInsets.only(
                      top:
                      10,
                    ),
                    child:
                    LinearProgressIndicator(),
                  ),
              ],
            ),

            const SizedBox(
              height:
              16,
            ),

            // ================================================
            // PASSWORD CHANGE
            // ================================================

            if (emailPasswordUser)
              _SecurityCard(
                title:
                'Change Password',

                children: [
                  Container(
                    width:
                    double.infinity,

                    padding:
                    const EdgeInsets.all(
                      11,
                    ),

                    decoration:
                    BoxDecoration(
                      color:
                      AppColors.primary
                          .withOpacity(
                        0.05,
                      ),

                      borderRadius:
                      BorderRadius.circular(
                        11,
                      ),
                    ),

                    child:
                    const Row(
                      children: [
                        Icon(
                          Icons.verified_user_outlined,
                          color:
                          AppColors.primary,
                          size:
                          18,
                        ),

                        SizedBox(
                          width:
                          8,
                        ),

                        Expanded(
                          child:
                          Text(
                            'Your current password is required before a new password can be saved. Your device password manager may offer to update its saved credential.',
                            style:
                            TextStyle(
                              color:
                              AppColors.textSecondary,
                              fontSize:
                              9,
                              height:
                              1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(
                    height:
                    14,
                  ),

                  AutofillGroup(
                    child:
                    Form(
                      key:
                      passwordFormKey,

                      child:
                      Column(
                        children: [
                          TextFormField(
                            controller:
                            currentPasswordController,

                            enabled:
                            !loading,

                            obscureText:
                            hideCurrentPassword,

                            autofillHints:
                            const [
                              AutofillHints.password,
                            ],

                            decoration:
                            _securityInput(
                              hint:
                              'Current password',

                              icon:
                              Icons.lock_person_outlined,

                              suffix:
                              IconButton(
                                onPressed: () {
                                  setState(() {
                                    hideCurrentPassword =
                                    !hideCurrentPassword;
                                  });
                                },

                                icon:
                                Icon(
                                  hideCurrentPassword
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                ),
                              ),
                            ),

                            validator:
                                (value) {
                              if (value == null ||
                                  value.isEmpty) {
                                return 'Current password is required.';
                              }

                              return null;
                            },
                          ),

                          const SizedBox(
                            height:
                            12,
                          ),

                          TextFormField(
                            controller:
                            newPasswordController,

                            enabled:
                            !loading,

                            obscureText:
                            hideNewPassword,

                            autofillHints:
                            const [
                              AutofillHints.newPassword,
                            ],

                            decoration:
                            _securityInput(
                              hint:
                              'New password',

                              icon:
                              Icons.lock_outline,

                              suffix:
                              IconButton(
                                onPressed: () {
                                  setState(() {
                                    hideNewPassword =
                                    !hideNewPassword;
                                  });
                                },

                                icon:
                                Icon(
                                  hideNewPassword
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                ),
                              ),
                            ),

                            validator:
                            validatePassword,
                          ),

                          const SizedBox(
                            height:
                            12,
                          ),

                          TextFormField(
                            controller:
                            confirmPasswordController,

                            enabled:
                            !loading,

                            obscureText:
                            hideConfirmPassword,

                            autofillHints:
                            const [
                              AutofillHints.newPassword,
                            ],

                            decoration:
                            _securityInput(
                              hint:
                              'Confirm new password',

                              icon:
                              Icons.lock_reset_outlined,

                              suffix:
                              IconButton(
                                onPressed: () {
                                  setState(() {
                                    hideConfirmPassword =
                                    !hideConfirmPassword;
                                  });
                                },

                                icon:
                                Icon(
                                  hideConfirmPassword
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                ),
                              ),
                            ),

                            validator:
                                (value) {
                              if (value == null ||
                                  value.isEmpty) {
                                return 'Please confirm the new password.';
                              }

                              if (value !=
                                  newPasswordController.text) {
                                return 'Passwords do not match.';
                              }

                              return null;
                            },
                          ),

                          const SizedBox(
                            height:
                            15,
                          ),

                          SizedBox(
                            width:
                            double.infinity,

                            height:
                            50,

                            child:
                            ElevatedButton.icon(
                              style:
                              ElevatedButton.styleFrom(
                                backgroundColor:
                                AppColors.primaryDark,
                              ),

                              onPressed:
                              loading
                                  ? null
                                  : changePassword,

                              icon:
                              const Icon(
                                Icons.security,
                              ),

                              label:
                              const Text(
                                'Verify & Change Password',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              )
            else
              _SecurityCard(
                title:
                'Password',

                children:
                const [
                  _SecurityNote(
                    icon:
                    Icons.account_circle_outlined,

                    title:
                    'Google Sign-In Account',

                    message:
                    'This account uses Google Sign-In, so a separate SmartCity password is not required.',
                  ),
                ],
              ),

            const SizedBox(
              height:
              16,
            ),

            // ================================================
            // CURRENT SESSION
            // ================================================

            _SecurityCard(
              title:
              'Current Session',

              children: [
                _SecurityInfoRow(
                  icon:
                  Icons.alternate_email,

                  title:
                  'Account',

                  value:
                  sessionInfo[
                  'email'] ??
                      'Unknown',
                ),

                _SecurityInfoRow(
                  icon:
                  Icons.login_outlined,

                  title:
                  'Login Method',

                  value:
                  sessionInfo[
                  'sign_in_method'] ??
                      'Unknown',
                ),

                _SecurityInfoRow(
                  icon:
                  Icons.verified_outlined,

                  title:
                  'Verification',

                  value:
                  sessionInfo[
                  'email_verified'] ??
                      'Unknown',
                ),
              ],
            ),

            const SizedBox(
              height:
              16,
            ),

            // ================================================
            // SECURITY OPTIONS
            // ================================================

            _SecurityCard(
              title:
              'Security Options',

              children: [
                _SecurityAction(
                  icon:
                  Icons.history,

                  title:
                  'Account Activity',

                  subtitle:
                  'Review recent account and security activity',

                  onTap:
                  openActivity,
                ),

                const Divider(
                  color:
                  AppColors.border,
                ),

                _SecurityAction(
                  icon:
                  Icons.lock_outline,

                  title:
                  'Quick Lock',

                  subtitle:
                  'Lock SmartCity immediately and require authentication to continue',

                  onTap:
                  quickLock,
                ),

                const Divider(
                  color:
                  AppColors.border,
                ),

                _SecurityAction(
                  icon:
                  Icons.logout,

                  title:
                  'Sign Out',

                  subtitle:
                  quickLoginEnabled
                      ? 'Return to Login and choose Quick Login, Email, or Google'
                      : 'End the current session and return to normal Login',

                  onTap:
                  logout,
                ),

                const Divider(
                  color:
                  AppColors.border,
                ),

                _SecurityAction(
                  icon:
                  Icons.phonelink_erase_outlined,

                  title:
                  'Forget This Device',

                  subtitle:
                  'Remove Quick Login, remembered account information, and end this trusted session',

                  onTap:
                  forgetThisDevice,
                ),
              ],
            ),

            const SizedBox(
              height:
              16,
            ),

            // ================================================
            // DANGER ZONE
            // ================================================

            Container(
              padding:
              const EdgeInsets.all(
                15,
              ),

              decoration:
              BoxDecoration(
                color:
                AppColors.danger
                    .withOpacity(
                  0.05,
                ),

                borderRadius:
                BorderRadius.circular(
                  16,
                ),

                border:
                Border.all(
                  color:
                  AppColors.danger
                      .withOpacity(
                    0.55,
                  ),
                ),
              ),

              child:
              Column(
                crossAxisAlignment:
                CrossAxisAlignment.start,

                children: [
                  const Row(
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        color:
                        AppColors.danger,
                      ),

                      SizedBox(
                        width:
                        8,
                      ),

                      Text(
                        'Danger Zone',
                        style:
                        TextStyle(
                          color:
                          AppColors.danger,
                          fontWeight:
                          FontWeight.bold,
                          fontSize:
                          14,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(
                    height:
                    9,
                  ),

                  Text(
                    emailPasswordUser
                        ? 'Your current password will be required before an account deletion request can be submitted.'
                        : 'Google verification will be required before an account deletion request can be submitted.',

                    style:
                    const TextStyle(
                      color:
                      AppColors.textSecondary,
                      fontSize:
                      10,
                      height:
                      1.4,
                    ),
                  ),

                  const SizedBox(
                    height:
                    14,
                  ),

                  SizedBox(
                    width:
                    double.infinity,

                    child:
                    OutlinedButton.icon(
                      style:
                      OutlinedButton.styleFrom(
                        side:
                        const BorderSide(
                          color:
                          AppColors.danger,
                        ),
                      ),

                      onPressed:
                      loading
                          ? null
                          : requestAccountDeletion,

                      icon:
                      const Icon(
                        Icons.delete_forever_outlined,
                        color:
                        AppColors.danger,
                      ),

                      label:
                      const Text(
                        'Request Account Deletion',
                        style:
                        TextStyle(
                          color:
                          AppColors.danger,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(
              height:
              30,
            ),
          ],
        ),
      ),
    );
  }
}

// ================================================================
// SECURITY CARD
// ================================================================

class _SecurityCard
    extends StatelessWidget {
  final String title;

  final List<Widget> children;

  const _SecurityCard({
    required this.title,
    required this.children,
  });

  @override
  Widget build(
      BuildContext context,
      ) {
    return Container(
      padding:
      const EdgeInsets.all(
        15,
      ),

      decoration:
      BoxDecoration(
        color:
        AppColors.surface,

        borderRadius:
        BorderRadius.circular(
          16,
        ),

        border:
        Border.all(
          color:
          AppColors.border,
        ),
      ),

      child:
      Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,

        children: [
          Text(
            title,

            style:
            const TextStyle(
              fontSize:
              14,

              fontWeight:
              FontWeight.bold,
            ),
          ),

          const SizedBox(
            height:
            12,
          ),

          ...children,
        ],
      ),
    );
  }
}

// ================================================================
// SECURITY INFO ROW
// ================================================================

class _SecurityInfoRow
    extends StatelessWidget {
  final IconData icon;

  final String title;

  final String value;

  final Color? valueColor;

  const _SecurityInfoRow({
    required this.icon,
    required this.title,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(
      BuildContext context,
      ) {
    return Padding(
      padding:
      const EdgeInsets.symmetric(
        vertical:
        8,
      ),

      child:
      Row(
        children: [
          Icon(
            icon,
            color:
            AppColors.primary,
            size:
            20,
          ),

          const SizedBox(
            width:
            11,
          ),

          Expanded(
            child:
            Text(
              title,
              style:
              const TextStyle(
                color:
                AppColors.textSecondary,
                fontSize:
                11,
              ),
            ),
          ),

          Flexible(
            child:
            Text(
              value,
              textAlign:
              TextAlign.right,
              style:
              TextStyle(
                color:
                valueColor ??
                    Colors.white,
                fontSize:
                11,
                fontWeight:
                FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ================================================================
// SECURITY ACTION
// ================================================================

class _SecurityAction
    extends StatelessWidget {
  final IconData icon;

  final String title;

  final String subtitle;

  final VoidCallback onTap;

  const _SecurityAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(
      BuildContext context,
      ) {
    return ListTile(
      contentPadding:
      EdgeInsets.zero,

      leading:
      Icon(
        icon,
        color:
        AppColors.primary,
      ),

      title:
      Text(
        title,
        style:
        const TextStyle(
          fontSize:
          12,
          fontWeight:
          FontWeight.bold,
        ),
      ),

      subtitle:
      Text(
        subtitle,
        style:
        const TextStyle(
          color:
          AppColors.textSecondary,
          fontSize:
          9,
        ),
      ),

      trailing:
      const Icon(
        Icons.chevron_right,
        color:
        AppColors.textSecondary,
      ),

      onTap:
      onTap,
    );
  }
}

// ================================================================
// SECURITY NOTE
// ================================================================

class _SecurityNote
    extends StatelessWidget {
  final IconData icon;

  final String title;

  final String message;

  const _SecurityNote({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(
      BuildContext context,
      ) {
    return Container(
      padding:
      const EdgeInsets.all(
        12,
      ),

      decoration:
      BoxDecoration(
        color:
        AppColors.primary
            .withOpacity(
          0.06,
        ),

        borderRadius:
        BorderRadius.circular(
          12,
        ),

        border:
        Border.all(
          color:
          AppColors.primaryDark,
        ),
      ),

      child:
      Row(
        crossAxisAlignment:
        CrossAxisAlignment.start,

        children: [
          Icon(
            icon,
            color:
            AppColors.primary,
          ),

          const SizedBox(
            width:
            10,
          ),

          Expanded(
            child:
            Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,

              children: [
                Text(
                  title,
                  style:
                  const TextStyle(
                    fontWeight:
                    FontWeight.bold,
                    fontSize:
                    11,
                  ),
                ),

                const SizedBox(
                  height:
                  4,
                ),

                Text(
                  message,
                  style:
                  const TextStyle(
                    color:
                    AppColors.textSecondary,
                    fontSize:
                    10,
                    height:
                    1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ================================================================
// SECURITY INPUT
// ================================================================

InputDecoration _securityInput({
  required String hint,
  required IconData icon,
  Widget? suffix,
}) {
  return InputDecoration(
    hintText:
    hint,

    prefixIcon:
    Icon(
      icon,
      color:
      AppColors.textSecondary,
    ),

    suffixIcon:
    suffix,

    filled:
    true,

    fillColor:
    AppColors.background,

    enabledBorder:
    OutlineInputBorder(
      borderRadius:
      BorderRadius.circular(
        13,
      ),

      borderSide:
      const BorderSide(
        color:
        AppColors.border,
      ),
    ),

    focusedBorder:
    OutlineInputBorder(
      borderRadius:
      BorderRadius.circular(
        13,
      ),

      borderSide:
      const BorderSide(
        color:
        AppColors.primary,
      ),
    ),

    errorBorder:
    OutlineInputBorder(
      borderRadius:
      BorderRadius.circular(
        13,
      ),

      borderSide:
      const BorderSide(
        color:
        AppColors.danger,
      ),
    ),

    focusedErrorBorder:
    OutlineInputBorder(
      borderRadius:
      BorderRadius.circular(
        13,
      ),

      borderSide:
      const BorderSide(
        color:
        AppColors.danger,
      ),
    ),
  );
}