import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/auth_service.dart';
import '../../theme/app_colors.dart';
import 'account_already_exists_screen.dart';
import 'email_verification_screen.dart';
import '../../services/email_verification_security_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({
    super.key,
  });

  @override
  State<RegisterScreen> createState() =>
      _RegisterScreenState();
}

class _RegisterScreenState
    extends State<RegisterScreen> {

  final GlobalKey<FormState> _formKey =
  GlobalKey<FormState>();

  final TextEditingController fullNameController =
  TextEditingController();

  final TextEditingController emailController =
  TextEditingController();

  final TextEditingController phoneController =
  TextEditingController();

  final TextEditingController passwordController =
  TextEditingController();

  final TextEditingController confirmPasswordController =
  TextEditingController();

  final AuthService authService =
  AuthService();

  final EmailVerificationSecurityService
  emailVerificationSecurityService =
  EmailVerificationSecurityService();

  final ImagePicker _imagePicker =
  ImagePicker();

  File? selectedProfileImage;

  bool loading = false;

  bool obscurePassword = true;

  bool obscureConfirmPassword = true;

  // ============================================================
  // INITIALIZATION
  // ============================================================

  @override
  void initState() {
    super.initState();

    passwordController.addListener(
      _passwordChanged,
    );

    confirmPasswordController.addListener(
      _passwordChanged,
    );
  }

  void _passwordChanged() {
    if (!mounted) {
      return;
    }

    setState(() {});
  }

  // ============================================================
  // PASSWORD REQUIREMENTS
  // ============================================================

  bool get hasMinimumLength =>
      passwordController.text.length >= 8;

  bool get hasRecommendedLength =>
      passwordController.text.length >= 12;

  bool get hasUppercase =>
      RegExp(
        r'[A-Z]',
      ).hasMatch(
        passwordController.text,
      );

  bool get hasLowercase =>
      RegExp(
        r'[a-z]',
      ).hasMatch(
        passwordController.text,
      );

  bool get hasNumber =>
      RegExp(
        r'[0-9]',
      ).hasMatch(
        passwordController.text,
      );

  bool get hasSpecialCharacter =>
      RegExp(
        r'[!@#$%^&*(),.?":{}|<>]',
      ).hasMatch(
        passwordController.text,
      );

  bool get passwordRequirementsSatisfied =>
      hasMinimumLength &&
          hasUppercase &&
          hasLowercase &&
          hasNumber &&
          hasSpecialCharacter;

  // ============================================================
  // PASSWORD STRENGTH
  // ============================================================

  int get passwordStrengthScore {
    final String password =
        passwordController.text;

    if (password.isEmpty) {
      return 0;
    }

    int score = 0;

    if (password.length >= 8) {
      score++;
    }

    if (
    hasUppercase &&
        hasLowercase
    ) {
      score++;
    }

    if (hasNumber) {
      score++;
    }

    if (hasSpecialCharacter) {
      score++;
    }

    if (password.length >= 12) {
      score++;
    }

    return score;
  }

  String get passwordStrengthLabel {
    final int score =
        passwordStrengthScore;

    if (score == 0) {
      return 'Not entered';
    }

    if (score <= 2) {
      return 'Weak';
    }

    if (score <= 4) {
      return 'Medium';
    }

    return 'Strong';
  }

  Color get passwordStrengthColor {
    final int score =
        passwordStrengthScore;

    if (score == 0) {
      return AppColors.textSecondary;
    }

    if (score <= 2) {
      return AppColors.danger;
    }

    if (score <= 4) {
      return AppColors.warning;
    }

    return AppColors.success;
  }

  double get passwordStrengthProgress {
    final int score =
        passwordStrengthScore;

    if (score == 0) {
      return 0.0;
    }

    return score / 5;
  }

  // ============================================================
  // CONFIRM PASSWORD STATUS
  // ============================================================

  bool get passwordsMatch =>
      confirmPasswordController.text.isNotEmpty &&
          confirmPasswordController.text ==
              passwordController.text;

  bool get confirmPasswordHasValue =>
      confirmPasswordController.text.isNotEmpty;

  // ============================================================
// FULL NAME VALIDATION
// ============================================================

  String? validateFullName(
      String? value,
      ) {
    final String name =
        value?.trim() ?? '';

    if (name.isEmpty) {
      return 'Full name is required.';
    }

    if (name.length < 3) {
      return 'Please enter your full name.';
    }

    if (name.length > 80) {
      return 'Full name is too long.';
    }

    // Must contain at least 2 alphabetic characters.
    final int letterCount =
        RegExp(
          r'[A-Za-z]',
        ).allMatches(
          name,
        ).length;

    if (letterCount < 2) {
      return 'Please enter a valid name.';
    }

    // Allow:
    // letters
    // spaces
    // apostrophes
    // hyphens
    // periods
    //
    // Examples:
    // Ahmad Razif bin Abdullah
    // Lee Wei-Jian
    // O'Connor
    // S. Kumar
    final RegExp allowedNamePattern =
    RegExp(
      r"^[A-Za-z][A-Za-z .'-]*[A-Za-z.]$",
    );

    if (
    !allowedNamePattern.hasMatch(
      name,
    )
    ) {
      return 'Name can only contain letters, spaces, '
          'apostrophes, periods and hyphens.';
    }

    // Reject excessive repeated characters.
    if (
    RegExp(
      r'(.)\1{4,}',
      caseSensitive:
      false,
    ).hasMatch(
      name,
    )
    ) {
      return 'Please enter a meaningful name.';
    }

    return null;
  }

// ============================================================
// EMAIL VALIDATION
// ============================================================

  String? validateEmail(
      String? value,
      ) {
    final String email =
        value
            ?.trim()
            .toLowerCase() ??
            '';

    if (email.isEmpty) {
      return 'Email is required.';
    }

    if (
    email.contains(
      ' ',
    )
    ) {
      return 'Email address cannot contain spaces.';
    }

    if (
    email.length >
        254
    ) {
      return 'Email address is too long.';
    }

    final RegExp emailPattern =
    RegExp(
      r'^[A-Za-z0-9.!#$%&''*+/=?^_`{|}~-]+@'
      r'[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?'
      r'(?:\.[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?)+$',
    );

    if (
    !emailPattern.hasMatch(
      email,
    )
    ) {
      return 'Enter a valid email address.';
    }

    return null;
  }

// ============================================================
// MALAYSIA PHONE NORMALIZATION
//
// Accepted examples:
//
// 0123456789
// 012-3456789
// 012 345 6789
// +60123456789
// +60 12-345 6789
// 60123456789
//
// Saved format:
//
// +60123456789
// ============================================================

  String normalizeMalaysiaPhone(
      String value,
      ) {
    String phone =
    value
        .trim()
        .replaceAll(
      RegExp(
        r'[\s()-]',
      ),
      '',
    );

    if (
    phone.startsWith(
      '+60',
    )
    ) {
      phone =
      '0${phone.substring(3)}';
    } else if (
    phone.startsWith(
      '60',
    )
    ) {
      phone =
      '0${phone.substring(2)}';
    }

    if (
    phone.startsWith(
      '0',
    )
    ) {
      return '+60${phone.substring(1)}';
    }

    return phone;
  }

// ============================================================
// MALAYSIA PHONE VALIDATION
// ============================================================

  String? validateMalaysiaPhone(
      String? value,
      ) {
    final String raw =
        value?.trim() ?? '';

    if (raw.isEmpty) {
      return 'Phone number is required.';
    }

    // Only allow digits, spaces, +, -, and parentheses.
    if (
    !RegExp(
      r'^[0-9+\-\s()]+$',
    ).hasMatch(
      raw,
    )
    ) {
      return 'Phone number contains invalid characters.';
    }

    String cleaned =
    raw.replaceAll(
      RegExp(
        r'[\s()-]',
      ),
      '',
    );

    // Convert +60 / 60 to local format for validation.
    if (
    cleaned.startsWith(
      '+60',
    )
    ) {
      cleaned =
      '0${cleaned.substring(3)}';
    } else if (
    cleaned.startsWith(
      '60',
    )
    ) {
      cleaned =
      '0${cleaned.substring(2)}';
    }

    // Malaysia mobile number:
    //
    // Starts with 01
    // followed by 8 or 9 digits.
    //
    // Total local length:
    // 10 or 11 digits.
    final RegExp malaysiaMobilePattern =
    RegExp(
      r'^01\d{8,9}$',
    );

    if (
    !malaysiaMobilePattern.hasMatch(
      cleaned,
    )
    ) {
      return 'Enter a valid Malaysia mobile number.';
    }

    return null;
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

    if (
    !RegExp(
      r'[A-Z]',
    ).hasMatch(
      password,
    )
    ) {
      return 'Add at least one uppercase letter.';
    }

    if (
    !RegExp(
      r'[a-z]',
    ).hasMatch(
      password,
    )
    ) {
      return 'Add at least one lowercase letter.';
    }

    if (
    !RegExp(
      r'[0-9]',
    ).hasMatch(
      password,
    )
    ) {
      return 'Add at least one number.';
    }

    if (
    !RegExp(
      r'[!@#$%^&*(),.?":{}|<>]',
    ).hasMatch(
      password,
    )
    ) {
      return 'Add at least one special character.';
    }

    return null;
  }

  // ============================================================
  // PICK PROFILE IMAGE
  // ============================================================

  Future<void> pickImage(
      ImageSource source,
      ) async {
    try {
      final XFile? image =
      await _imagePicker.pickImage(
        source: source,
        imageQuality: 80,
        maxWidth: 1200,
      );

      if (image == null) {
        return;
      }

      if (!mounted) {
        return;
      }

      setState(() {
        selectedProfileImage =
            File(
              image.path,
            );
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      showMessage(
        'Unable to select image: $e',
      );
    }
  }

  // ============================================================
  // PROFILE IMAGE MENU
  // ============================================================

  void showImageOptions() {
    if (loading) {
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(22),
        ),
      ),
      builder: (
          bottomSheetContext,
          ) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              vertical: 12,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 45,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius:
                    BorderRadius.circular(
                      20,
                    ),
                  ),
                ),

                const SizedBox(height: 15),

                const Text(
                  'Profile Picture',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight:
                    FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 10),

                ListTile(
                  leading: const Icon(
                    Icons.camera_alt_outlined,
                    color: AppColors.primary,
                  ),
                  title: const Text(
                    'Take Photo',
                  ),
                  subtitle: const Text(
                    'Use your camera',
                    style: TextStyle(
                      color:
                      AppColors.textSecondary,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(
                      bottomSheetContext,
                    );

                    pickImage(
                      ImageSource.camera,
                    );
                  },
                ),

                ListTile(
                  leading: const Icon(
                    Icons.photo_library_outlined,
                    color: AppColors.primary,
                  ),
                  title: const Text(
                    'Choose from Gallery',
                  ),
                  subtitle: const Text(
                    'Select an existing photo',
                    style: TextStyle(
                      color:
                      AppColors.textSecondary,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(
                      bottomSheetContext,
                    );

                    pickImage(
                      ImageSource.gallery,
                    );
                  },
                ),

                if (
                selectedProfileImage != null
                )
                  ListTile(
                    leading: const Icon(
                      Icons.delete_outline,
                      color: AppColors.danger,
                    ),
                    title: const Text(
                      'Remove Photo',
                    ),
                    onTap: () {
                      Navigator.pop(
                        bottomSheetContext,
                      );

                      setState(() {
                        selectedProfileImage =
                        null;
                      });
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ============================================================
  // PROFILE IMAGE UPLOAD
  //
  // Normally not used during pending registration because
  // Confirm Email means no authenticated session exists yet.
  // Kept for compatibility.
  // ============================================================

  Future<String?> uploadProfileImage(
      String userId,
      ) async {
    if (
    selectedProfileImage == null
    ) {
      return null;
    }

    final String fileExtension =
    selectedProfileImage!
        .path
        .split('.')
        .last
        .toLowerCase();

    final String filePath =
        '$userId/'
        'profile_'
        '${DateTime.now().millisecondsSinceEpoch}.'
        '$fileExtension';

    await Supabase.instance.client.storage
        .from(
      'profile-images',
    )
        .upload(
      filePath,
      selectedProfileImage!,
      fileOptions: const FileOptions(
        cacheControl: '3600',
        upsert: true,
      ),
    );

    return filePath;
  }

  // ============================================================
  // UPDATE PROFILE IMAGE PATH
  // ============================================================

  Future<void> updateProfileImagePath({
    required String userId,
    required String imagePath,
  }) async {
    await Supabase.instance.client
        .from(
      'profiles',
    )
        .update({
      'profile_image_url':
      imagePath,

      'updated_at':
      DateTime.now()
          .toIso8601String(),
    })
        .eq(
      'id',
      userId,
    );
  }

  // ============================================================
  // REGISTER
  // ============================================================

  Future<void> register() async {
    if (loading) {
      return;
    }

    if (
    !(
        _formKey.currentState
            ?.validate() ??
            false
    )
    ) {
      return;
    }

    // ==========================================================
    // PASSWORD REQUIREMENTS
    // ==========================================================

    if (
    !passwordRequirementsSatisfied
    ) {
      showMessage(
        'Please complete all password requirements.',
      );

      return;
    }

    // ==========================================================
    // PASSWORD MATCH
    // ==========================================================

    if (!passwordsMatch) {
      showMessage(
        'Passwords do not match.',
      );

      return;
    }

    final String email =
    emailController.text
        .trim()
        .toLowerCase();

    setState(() {
      loading = true;
    });

    try {
      // ========================================================
      // STEP 1 — CHECK WHETHER EMAIL EXISTS
      // ========================================================

      final RegistrationEmailCheckResult
      emailCheck =
      await authService
          .checkRegistrationEmail(
        email,
      );

      if (!mounted) {
        return;
      }

      // ========================================================
      // EXISTING EMAIL
      // ========================================================

      if (emailCheck.exists) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) =>
                AccountAlreadyExistsScreen(
                  email: email,
                ),
          ),
        );

        return;
      }

      // ========================================================
      // STEP 2 — CREATE PENDING AUTH ACCOUNT
      // ========================================================

      final AuthResponse response =
      await authService.register(
        fullName:
        fullNameController.text
            .trim(),

        email:
        email,

        phone:
        phoneController.text
            .trim(),

        password:
        passwordController.text,
      );

      final User? user =
          response.user;

      if (user == null) {
        throw Exception(
          'Unable to start registration.',
        );
      }

      // ========================================================
      // START SMARTCITY EMAIL VERIFICATION WINDOW
      //
      // Initial verification email is valid in SmartCity for
      // 5 minutes.
      // ========================================================

      await emailVerificationSecurityService
          .startVerificationWindow(
        email,
      );

      // ========================================================
      // EMAIL VERIFICATION REQUIRED
      //
      // At this point the auth identity may exist, but SmartCity
      // does NOT consider the account active/successful yet.
      // ========================================================

      if (
      response.session != null &&
          user.emailConfirmedAt == null
      ) {
        await Supabase.instance.client.auth
            .signOut();
      }

      // ========================================================
      // PROFILE IMAGE
      //
      // Only upload immediately if a verified authenticated
      // session exists. Normally this will NOT run while Confirm
      // Email is enabled.
      // ========================================================

      if (
      selectedProfileImage != null &&
          response.session != null &&
          user.emailConfirmedAt != null
      ) {
        final String? imagePath =
        await uploadProfileImage(
          user.id,
        );

        if (imagePath != null) {
          await updateProfileImagePath(
            userId:
            user.id,

            imagePath:
            imagePath,
          );
        }
      }

      if (!mounted) {
        return;
      }

      // ========================================================
      // PENDING VERIFICATION
      // ========================================================

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) =>
              EmailVerificationScreen(
                email: email,
              ),
        ),
      );
    } on AuthException catch (e) {
      if (!mounted) {
        return;
      }

      showMessage(
        formatAuthError(
          e.message,
        ),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      final String message =
      e
          .toString()
          .replaceFirst(
        'Exception: ',
        '',
      )
          .trim();

      showMessage(
        message.isEmpty
            ? 'Unable to start registration. Please try again.'
            : message,
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
  // AUTH ERROR MESSAGE
  // ============================================================

  String formatAuthError(
      String message,
      ) {
    final String lower =
    message.toLowerCase();

    if (
    lower.contains(
      'user already registered',
    ) ||
        lower.contains(
          'already exists',
        )
    ) {
      return 'This email address is already registered. '
          'Please sign in instead.';
    }

    if (
    lower.contains(
      'invalid email',
    )
    ) {
      return 'Please enter a valid email address.';
    }

    if (
    lower.contains(
      'email rate limit',
    ) ||
        lower.contains(
          'too many',
        )
    ) {
      return 'Too many registration or verification requests. '
          'Please wait and try again.';
    }

    return message;
  }

  // ============================================================
  // MESSAGE
  // ============================================================

  void showMessage(
      String message,
      ) {
    ScaffoldMessenger.of(
      context,
    ).hideCurrentSnackBar();

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(
              Icons.info_outline,
              color: Colors.white,
            ),

            const SizedBox(
              width: 10,
            ),

            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        behavior:
        SnackBarBehavior.floating,
        duration:
        const Duration(
          seconds: 4,
        ),
      ),
    );
  }

  // ============================================================
  // INPUT DECORATION
  // ============================================================

  InputDecoration inputDecoration(
      String hint, {
        Widget? prefixIcon,
        Widget? suffixIcon,
      }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(
        color: AppColors.textSecondary,
      ),
      filled: true,
      fillColor: AppColors.surface,
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      contentPadding:
      const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 17,
      ),
      enabledBorder:
      OutlineInputBorder(
        borderRadius:
        BorderRadius.circular(
          14,
        ),
        borderSide:
        const BorderSide(
          color: AppColors.border,
        ),
      ),
      focusedBorder:
      OutlineInputBorder(
        borderRadius:
        BorderRadius.circular(
          14,
        ),
        borderSide:
        const BorderSide(
          color: AppColors.primary,
          width: 1.5,
        ),
      ),
      errorBorder:
      OutlineInputBorder(
        borderRadius:
        BorderRadius.circular(
          14,
        ),
        borderSide:
        const BorderSide(
          color: AppColors.danger,
        ),
      ),
      focusedErrorBorder:
      OutlineInputBorder(
        borderRadius:
        BorderRadius.circular(
          14,
        ),
        borderSide:
        const BorderSide(
          color: AppColors.danger,
        ),
      ),
    );
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    passwordController.removeListener(
      _passwordChanged,
    );

    confirmPasswordController.removeListener(
      _passwordChanged,
    );

    fullNameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();

    super.dispose();
  }

  // ============================================================
  // UI
  // ============================================================

  @override
  Widget build(
      BuildContext context,
      ) {
    return Scaffold(
      backgroundColor:
      AppColors.background,

      body: SafeArea(
        child: SingleChildScrollView(
          padding:
          const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 18,
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                // =================================================
                // BACK BUTTON
                // =================================================

                Container(
                  decoration: BoxDecoration(
                    color:
                    AppColors.surface,
                    borderRadius:
                    BorderRadius.circular(
                      12,
                    ),
                    border: Border.all(
                      color:
                      AppColors.border,
                    ),
                  ),
                  child: IconButton(
                    onPressed: loading
                        ? null
                        : () {
                      Navigator.pop(
                        context,
                      );
                    },
                    icon: const Icon(
                      Icons.arrow_back,
                    ),
                  ),
                ),

                const SizedBox(
                  height: 22,
                ),

                // =================================================
                // HEADER
                // =================================================

                const Text(
                  'Create Account',
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight:
                    FontWeight.bold,
                  ),
                ),

                const SizedBox(
                  height: 7,
                ),

                const Text(
                  'Join the SmartCity community',
                  style: TextStyle(
                    color:
                    AppColors.textSecondary,
                    fontSize: 15,
                  ),
                ),

                const SizedBox(
                  height: 7,
                ),

                const Text(
                  'Your registration is completed only after '
                      'your email address has been verified.',
                  style: TextStyle(
                    color:
                    AppColors.primary,
                    fontSize: 11,
                    fontWeight:
                    FontWeight.w600,
                  ),
                ),

                const SizedBox(
                  height: 25,
                ),

                // =================================================
                // PROFILE PHOTO
                // =================================================

                Center(
                  child: GestureDetector(
                    onTap: loading
                        ? null
                        : showImageOptions,
                    child: Stack(
                      clipBehavior:
                      Clip.none,
                      children: [
                        Container(
                          width: 92,
                          height: 92,
                          decoration:
                          BoxDecoration(
                            shape:
                            BoxShape.circle,
                            color:
                            AppColors.surface,
                            border:
                            Border.all(
                              color:
                              AppColors.primary,
                              width: 1.5,
                            ),
                            image:
                            selectedProfileImage !=
                                null
                                ? DecorationImage(
                              image:
                              FileImage(
                                selectedProfileImage!,
                              ),
                              fit:
                              BoxFit.cover,
                            )
                                : null,
                          ),
                          child:
                          selectedProfileImage ==
                              null
                              ? const Icon(
                            Icons.person,
                            size: 46,
                            color:
                            AppColors.primary,
                          )
                              : null,
                        ),

                        Positioned(
                          bottom: -2,
                          right: -2,
                          child: Container(
                            width: 31,
                            height: 31,
                            decoration:
                            BoxDecoration(
                              color:
                              AppColors.primary,
                              shape:
                              BoxShape.circle,
                              border:
                              Border.all(
                                color:
                                AppColors.background,
                                width: 3,
                              ),
                            ),
                            child:
                            const Icon(
                              Icons.add_a_photo,
                              color:
                              Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(
                  height: 12,
                ),

                const Center(
                  child: Text(
                    'Tap to add profile picture',
                    style: TextStyle(
                      color:
                      AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ),

                const SizedBox(
                  height: 28,
                ),

                // =================================================
                // FULL NAME
                // =================================================

                const _FieldLabel(
                  'FULL NAME',
                ),

                const SizedBox(
                  height: 8,
                ),

                TextFormField(
                  controller:
                  fullNameController,
                  enabled: !loading,
                  textCapitalization:
                  TextCapitalization.words,
                  autofillHints:
                  const [
                    AutofillHints.name,
                  ],
                  decoration:
                  inputDecoration(
                    'Ahmad Razif bin Abdullah',
                    prefixIcon:
                    const Icon(
                      Icons.person_outline,
                    ),
                  ),
                  validator: validateFullName,
                ),

                const SizedBox(
                  height: 18,
                ),

                // =================================================
                // EMAIL
                // =================================================

                const _FieldLabel(
                  'EMAIL ADDRESS',
                ),

                const SizedBox(
                  height: 8,
                ),

                TextFormField(
                  controller:
                  emailController,
                  enabled: !loading,
                  keyboardType:
                  TextInputType
                      .emailAddress,
                  autocorrect: false,
                  autofillHints:
                  const [
                    AutofillHints.email,
                  ],
                  decoration:
                  inputDecoration(
                    'ahmad@gmail.com',
                    prefixIcon:
                    const Icon(
                      Icons.email_outlined,
                    ),
                  ),
                  validator: validateEmail,
                ),

                const SizedBox(
                  height: 18,
                ),

                // =================================================
                // PHONE
                // =================================================

                const _FieldLabel(
                  'PHONE NUMBER',
                ),

                const SizedBox(
                  height: 8,
                ),

                TextFormField(
                  controller:
                  phoneController,
                  enabled: !loading,
                  keyboardType:
                  TextInputType.phone,
                  autofillHints:
                  const [
                    AutofillHints
                        .telephoneNumber,
                  ],
                  decoration:
                  inputDecoration(
                    '+60 12-345 6789',
                    prefixIcon:
                    const Icon(
                      Icons.phone_outlined,
                    ),
                  ),
                  validator: validateMalaysiaPhone,
                ),

                const SizedBox(
                  height: 18,
                ),

                // =================================================
                // PASSWORD
                // =================================================

                const _FieldLabel(
                  'PASSWORD',
                ),

                const SizedBox(
                  height: 8,
                ),

                TextFormField(
                  controller:
                  passwordController,
                  enabled: !loading,
                  obscureText:
                  obscurePassword,
                  autofillHints:
                  const [
                    AutofillHints
                        .newPassword,
                  ],
                  decoration:
                  inputDecoration(
                    '••••••••',
                    prefixIcon:
                    const Icon(
                      Icons.lock_outline,
                    ),
                    suffixIcon:
                    IconButton(
                      onPressed:
                      loading
                          ? null
                          : () {
                        setState(() {
                          obscurePassword =
                          !obscurePassword;
                        });
                      },
                      icon: Icon(
                        obscurePassword
                            ? Icons.visibility
                            : Icons
                            .visibility_off,
                      ),
                    ),
                  ),
                  validator:
                  validatePassword,
                ),

                const SizedBox(
                  height: 10,
                ),

                // =================================================
                // PASSWORD STRENGTH
                // =================================================

                _PasswordStrengthCard(
                  label:
                  passwordStrengthLabel,
                  progress:
                  passwordStrengthProgress,
                  strengthColor:
                  passwordStrengthColor,
                  hasMinimumLength:
                  hasMinimumLength,
                  hasUppercase:
                  hasUppercase,
                  hasLowercase:
                  hasLowercase,
                  hasNumber:
                  hasNumber,
                  hasSpecialCharacter:
                  hasSpecialCharacter,
                  hasRecommendedLength:
                  hasRecommendedLength,
                ),

                const SizedBox(
                  height: 18,
                ),

                // =================================================
                // CONFIRM PASSWORD
                // =================================================

                const _FieldLabel(
                  'CONFIRM PASSWORD',
                ),

                const SizedBox(
                  height: 8,
                ),

                TextFormField(
                  controller:
                  confirmPasswordController,
                  enabled: !loading,
                  obscureText:
                  obscureConfirmPassword,
                  textInputAction:
                  TextInputAction.done,
                  autofillHints:
                  const [
                    AutofillHints
                        .newPassword,
                  ],
                  decoration:
                  inputDecoration(
                    '••••••••',
                    prefixIcon:
                    const Icon(
                      Icons
                          .lock_reset_outlined,
                    ),
                    suffixIcon:
                    IconButton(
                      onPressed:
                      loading
                          ? null
                          : () {
                        setState(() {
                          obscureConfirmPassword =
                          !obscureConfirmPassword;
                        });
                      },
                      icon: Icon(
                        obscureConfirmPassword
                            ? Icons.visibility
                            : Icons
                            .visibility_off,
                      ),
                    ),
                  ),
                  validator: (
                      value,
                      ) {
                    if (
                    value == null ||
                        value.isEmpty
                    ) {
                      return 'Please confirm your password.';
                    }

                    if (
                    value !=
                        passwordController.text
                    ) {
                      return 'Passwords do not match.';
                    }

                    return null;
                  },
                  onFieldSubmitted: (
                      _,
                      ) {
                    if (!loading) {
                      register();
                    }
                  },
                ),

                if (
                confirmPasswordHasValue
                ) ...[
                  const SizedBox(
                    height: 8,
                  ),

                  _PasswordMatchIndicator(
                    matches:
                    passwordsMatch,
                  ),
                ],

                const SizedBox(
                  height: 28,
                ),

                // =================================================
                // CREATE ACCOUNT BUTTON
                // =================================================

                SizedBox(
                  width:
                  double.infinity,
                  height: 56,
                  child:
                  ElevatedButton(
                    style:
                    ElevatedButton
                        .styleFrom(
                      backgroundColor:
                      AppColors.primaryDark,
                      foregroundColor:
                      Colors.white,
                      disabledBackgroundColor:
                      AppColors.primaryDark
                          .withOpacity(
                        0.5,
                      ),
                      shape:
                      RoundedRectangleBorder(
                        borderRadius:
                        BorderRadius.circular(
                          15,
                        ),
                      ),
                    ),
                    onPressed:
                    loading
                        ? null
                        : register,
                    child:
                    loading
                        ? const SizedBox(
                      width: 22,
                      height: 22,
                      child:
                      CircularProgressIndicator(
                        strokeWidth:
                        2.5,
                        color:
                        Colors.white,
                      ),
                    )
                        : const Text(
                      'Create Account',
                      style:
                      TextStyle(
                        fontSize: 17,
                        fontWeight:
                        FontWeight.bold,
                      ),
                    ),
                  ),
                ),

                const SizedBox(
                  height: 18,
                ),

                // =================================================
                // EMAIL VERIFICATION NOTICE
                // =================================================

                Container(
                  width:
                  double.infinity,
                  padding:
                  const EdgeInsets.all(
                    14,
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
                      13,
                    ),
                    border:
                    Border.all(
                      color:
                      AppColors.primary
                          .withOpacity(
                        0.35,
                      ),
                    ),
                  ),
                  child:
                  const Row(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons
                            .mark_email_unread_outlined,
                        size: 18,
                        color:
                        AppColors.primary,
                      ),

                      SizedBox(
                        width: 10,
                      ),

                      Expanded(
                        child: Text(
                          'After registration, a verification email '
                              'will be sent to you. Your SmartCity account '
                              'is not considered active until the email '
                              'address has been verified.',
                          style:
                          TextStyle(
                            color:
                            AppColors.textSecondary,
                            fontSize: 11,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(
                  height: 12,
                ),

                // =================================================
                // CITIZEN NOTICE
                // =================================================

                Container(
                  width:
                  double.infinity,
                  padding:
                  const EdgeInsets.all(
                    14,
                  ),
                  decoration:
                  BoxDecoration(
                    color:
                    AppColors.surface,
                    borderRadius:
                    BorderRadius.circular(
                      13,
                    ),
                    border:
                    Border.all(
                      color:
                      AppColors.border,
                    ),
                  ),
                  child:
                  const Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 18,
                        color:
                        AppColors.primary,
                      ),

                      SizedBox(
                        width: 10,
                      ),

                      Expanded(
                        child: Text(
                          'New accounts are registered as Citizen accounts. '
                              'Worker and Admin roles are assigned separately.',
                          style:
                          TextStyle(
                            color:
                            AppColors.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(
                  height: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ================================================================
// PASSWORD STRENGTH CARD
// ================================================================

class _PasswordStrengthCard
    extends StatelessWidget {
  final String label;

  final double progress;

  final Color strengthColor;

  final bool hasMinimumLength;

  final bool hasUppercase;

  final bool hasLowercase;

  final bool hasNumber;

  final bool hasSpecialCharacter;

  final bool hasRecommendedLength;

  const _PasswordStrengthCard({
    required this.label,
    required this.progress,
    required this.strengthColor,
    required this.hasMinimumLength,
    required this.hasUppercase,
    required this.hasLowercase,
    required this.hasNumber,
    required this.hasSpecialCharacter,
    required this.hasRecommendedLength,
  });

  @override
  Widget build(
      BuildContext context,
      ) {
    return Container(
      width:
      double.infinity,
      padding:
      const EdgeInsets.all(
        14,
      ),
      decoration:
      BoxDecoration(
        color:
        AppColors.surface,
        borderRadius:
        BorderRadius.circular(
          13,
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
          Row(
            children: [
              const Text(
                'Password strength',
                style:
                TextStyle(
                  color:
                  AppColors.textSecondary,
                  fontSize: 11,
                  fontWeight:
                  FontWeight.w600,
                ),
              ),

              const Spacer(),

              Text(
                label,
                style:
                TextStyle(
                  color:
                  strengthColor,
                  fontSize: 11,
                  fontWeight:
                  FontWeight.bold,
                ),
              ),
            ],
          ),

          const SizedBox(
            height: 8,
          ),

          ClipRRect(
            borderRadius:
            BorderRadius.circular(
              20,
            ),
            child:
            LinearProgressIndicator(
              value:
              progress,
              minHeight: 6,
              backgroundColor:
              AppColors.border,
              color:
              strengthColor,
            ),
          ),

          const SizedBox(
            height: 13,
          ),

          _PasswordRequirement(
            satisfied:
            hasMinimumLength,
            text:
            'At least 8 characters',
          ),

          _PasswordRequirement(
            satisfied:
            hasUppercase,
            text:
            'At least 1 uppercase letter',
          ),

          _PasswordRequirement(
            satisfied:
            hasLowercase,
            text:
            'At least 1 lowercase letter',
          ),

          _PasswordRequirement(
            satisfied:
            hasNumber,
            text:
            'At least 1 number',
          ),

          _PasswordRequirement(
            satisfied:
            hasSpecialCharacter,
            text:
            'At least 1 special character',
          ),

          _PasswordRequirement(
            satisfied:
            hasRecommendedLength,
            text:
            '12+ characters recommended',
            optional:
            true,
          ),
        ],
      ),
    );
  }
}

// ================================================================
// PASSWORD REQUIREMENT
// ================================================================

class _PasswordRequirement
    extends StatelessWidget {
  final bool satisfied;

  final String text;

  final bool optional;

  const _PasswordRequirement({
    required this.satisfied,
    required this.text,
    this.optional = false,
  });

  @override
  Widget build(
      BuildContext context,
      ) {
    final Color color =
    satisfied
        ? AppColors.success
        : AppColors.textSecondary;

    return Padding(
      padding:
      const EdgeInsets.only(
        bottom: 6,
      ),
      child: Row(
        children: [
          Icon(
            satisfied
                ? Icons.check_circle
                : Icons
                .radio_button_unchecked,
            size: 15,
            color: color,
          ),

          const SizedBox(
            width: 7,
          ),

          Expanded(
            child: Text(
              optional
                  ? '$text (optional)'
                  : text,
              style: TextStyle(
                color: color,
                fontSize: 10,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ================================================================
// PASSWORD MATCH INDICATOR
// ================================================================

class _PasswordMatchIndicator
    extends StatelessWidget {
  final bool matches;

  const _PasswordMatchIndicator({
    required this.matches,
  });

  @override
  Widget build(
      BuildContext context,
      ) {
    final Color color =
    matches
        ? AppColors.success
        : AppColors.danger;

    return Row(
      children: [
        Icon(
          matches
              ? Icons
              .check_circle_outline
              : Icons.cancel_outlined,
          color: color,
          size: 16,
        ),

        const SizedBox(
          width: 7,
        ),

        Text(
          matches
              ? 'Passwords match'
              : 'Passwords do not match',
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight:
            FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

// ================================================================
// FIELD LABEL
// ================================================================

class _FieldLabel
    extends StatelessWidget {
  final String text;

  const _FieldLabel(
      this.text,
      );

  @override
  Widget build(
      BuildContext context,
      ) {
    return Text(
      text,
      style:
      const TextStyle(
        color:
        Color(
          0xFFA9C7EF,
        ),
        fontSize: 12,
        fontWeight:
        FontWeight.w600,
        letterSpacing: 0.4,
      ),
    );
  }
}