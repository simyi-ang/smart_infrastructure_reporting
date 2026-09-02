import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/auth_service.dart';
import '../../theme/app_colors.dart';
import 'email_verification_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();

  final fullNameController = TextEditingController();
  final emailController = TextEditingController();
  final phoneController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  final AuthService authService = AuthService();

  final ImagePicker _imagePicker = ImagePicker();

  File? selectedProfileImage;

  bool loading = false;
  bool obscurePassword = true;
  bool obscureConfirmPassword = true;

  // ============================================================
  // PASSWORD VALIDATION
  // ============================================================

  bool isStrongPassword(String password) {
    return password.length >= 8 &&
        RegExp(r'[A-Z]').hasMatch(password) &&
        RegExp(r'[a-z]').hasMatch(password) &&
        RegExp(r'[0-9]').hasMatch(password);
  }

  // ============================================================
  // PICK IMAGE
  // ============================================================

  Future<void> pickImage(ImageSource source) async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: source,
        imageQuality: 80,
        maxWidth: 1200,
      );

      if (image == null) {
        return;
      }

      setState(() {
        selectedProfileImage = File(image.path);
      });
    } catch (e) {
      if (!mounted) return;

      showMessage(
        'Unable to select image: $e',
      );
    }
  }

  // ============================================================
  // PROFILE IMAGE MENU
  // ============================================================

  void showImageOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(22),
        ),
      ),
      builder: (bottomSheetContext) {
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
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),

                const SizedBox(height: 15),

                const Text(
                  'Profile Picture',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
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
                      color: AppColors.textSecondary,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(bottomSheetContext);

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
                      color: AppColors.textSecondary,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(bottomSheetContext);

                    pickImage(
                      ImageSource.gallery,
                    );
                  },
                ),

                if (selectedProfileImage != null)
                  ListTile(
                    leading: const Icon(
                      Icons.delete_outline,
                      color: AppColors.danger,
                    ),
                    title: const Text(
                      'Remove Photo',
                    ),
                    onTap: () {
                      Navigator.pop(bottomSheetContext);

                      setState(() {
                        selectedProfileImage = null;
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
  // UPLOAD PROFILE IMAGE
  // ============================================================

  Future<String?> uploadProfileImage(
      String userId,
      ) async {
    if (selectedProfileImage == null) {
      return null;
    }

    final fileExtension =
    selectedProfileImage!.path.split('.').last.toLowerCase();

    final filePath =
        '$userId/profile_${DateTime.now().millisecondsSinceEpoch}.$fileExtension';

    await Supabase.instance.client.storage
        .from('profile-images')
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
        .from('profiles')
        .update({
      'profile_image_url': imagePath,
      'updated_at': DateTime.now().toIso8601String(),
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
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      loading = true;
    });

    try {
      final response = await authService.register(
        fullName: fullNameController.text,
        email: emailController.text,
        phone: phoneController.text,
        password: passwordController.text,
      );

      final user = response.user;

      if (user == null) {
        throw Exception(
          'Unable to create account.',
        );
      }

      // Upload selected profile image if a session exists.
      //
      // When email confirmation is enabled,
      // Supabase may return a user but no active session yet.
      //
      // Therefore image upload is attempted only when authenticated.
      if (selectedProfileImage != null &&
          response.session != null) {
        final imagePath = await uploadProfileImage(
          user.id,
        );

        if (imagePath != null) {
          await updateProfileImagePath(
            userId: user.id,
            imagePath: imagePath,
          );
        }
      }

      if (!mounted) {
        return;
      }

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => EmailVerificationScreen(
            email: emailController.text.trim(),
          ),
        ),
      );
    } on AuthException catch (e) {
      if (!mounted) return;

      showMessage(
        formatAuthError(e.message),
      );
    } catch (e) {
      if (!mounted) return;

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
  // AUTH ERROR MESSAGE
  // ============================================================

  String formatAuthError(String message) {
    final lower = message.toLowerCase();

    if (lower.contains(
      'user already registered',
    )) {
      return 'This email address is already registered.';
    }

    if (lower.contains(
      'invalid email',
    )) {
      return 'Please enter a valid email address.';
    }

    if (lower.contains(
      'email rate limit',
    )) {
      return 'Too many verification emails were requested. Please wait and try again.';
    }

    if (lower.contains(
      'password',
    )) {
      return message;
    }

    return message;
  }

  // ============================================================
  // MESSAGE
  // ============================================================

  void showMessage(String message) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
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
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 17,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(
          14,
        ),
        borderSide: const BorderSide(
          color: AppColors.border,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(
          14,
        ),
        borderSide: const BorderSide(
          color: AppColors.primary,
          width: 1.5,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(
          14,
        ),
        borderSide: const BorderSide(
          color: AppColors.danger,
        ),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(
          14,
        ),
        borderSide: const BorderSide(
          color: AppColors.danger,
        ),
      ),
    );
  }

  @override
  void dispose() {
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
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,

      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 18,
          ),

          child: Form(
            key: _formKey,

            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                // =================================================
                // BACK BUTTON
                // =================================================

                Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(
                      12,
                    ),
                    border: Border.all(
                      color: AppColors.border,
                    ),
                  ),

                  child: IconButton(
                    onPressed: loading
                        ? null
                        : () {
                      Navigator.pop(context);
                    },

                    icon: const Icon(
                      Icons.arrow_back,
                    ),
                  ),
                ),

                const SizedBox(height: 22),

                // =================================================
                // HEADER
                // =================================================

                const Text(
                  'Create Account',
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 7),

                const Text(
                  'Join the SmartCity community',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 15,
                  ),
                ),

                const SizedBox(height: 25),

                // =================================================
                // PROFILE PHOTO
                // =================================================

                Center(
                  child: GestureDetector(
                    onTap: loading
                        ? null
                        : showImageOptions,

                    child: Stack(
                      clipBehavior: Clip.none,

                      children: [
                        Container(
                          width: 92,
                          height: 92,

                          decoration: BoxDecoration(
                            shape: BoxShape.circle,

                            color: AppColors.surface,

                            border: Border.all(
                              color: AppColors.primary,
                              width: 1.5,
                            ),

                            image: selectedProfileImage != null
                                ? DecorationImage(
                              image: FileImage(
                                selectedProfileImage!,
                              ),
                              fit: BoxFit.cover,
                            )
                                : null,
                          ),

                          child: selectedProfileImage == null
                              ? const Icon(
                            Icons.person,
                            size: 46,
                            color: AppColors.primary,
                          )
                              : null,
                        ),

                        Positioned(
                          bottom: -2,
                          right: -2,

                          child: Container(
                            width: 31,
                            height: 31,

                            decoration: BoxDecoration(
                              color: AppColors.primary,

                              shape: BoxShape.circle,

                              border: Border.all(
                                color: AppColors.background,
                                width: 3,
                              ),
                            ),

                            child: const Icon(
                              Icons.add_a_photo,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                const Center(
                  child: Text(
                    'Tap to add profile picture',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ),

                const SizedBox(height: 28),

                // =================================================
                // FULL NAME
                // =================================================

                const _FieldLabel(
                  'FULL NAME',
                ),

                const SizedBox(height: 8),

                TextFormField(
                  controller: fullNameController,
                  enabled: !loading,

                  textCapitalization:
                  TextCapitalization.words,

                  decoration: inputDecoration(
                    'Ahmad Razif bin Abdullah',
                    prefixIcon: const Icon(
                      Icons.person_outline,
                    ),
                  ),

                  validator: (value) {
                    if (value == null ||
                        value.trim().isEmpty) {
                      return 'Full name is required.';
                    }

                    if (value.trim().length < 3) {
                      return 'Please enter a valid name.';
                    }

                    return null;
                  },
                ),

                const SizedBox(height: 18),

                // =================================================
                // EMAIL
                // =================================================

                const _FieldLabel(
                  'EMAIL ADDRESS',
                ),

                const SizedBox(height: 8),

                TextFormField(
                  controller: emailController,
                  enabled: !loading,

                  keyboardType:
                  TextInputType.emailAddress,

                  autocorrect: false,

                  decoration: inputDecoration(
                    'ahmad@gmail.com',
                    prefixIcon: const Icon(
                      Icons.email_outlined,
                    ),
                  ),

                  validator: (value) {
                    if (value == null ||
                        value.trim().isEmpty) {
                      return 'Email is required.';
                    }

                    final emailRegex = RegExp(
                      r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                    );

                    if (!emailRegex.hasMatch(
                      value.trim(),
                    )) {
                      return 'Enter a valid email address.';
                    }

                    return null;
                  },
                ),

                const SizedBox(height: 18),

                // =================================================
                // PHONE
                // =================================================

                const _FieldLabel(
                  'PHONE NUMBER',
                ),

                const SizedBox(height: 8),

                TextFormField(
                  controller: phoneController,
                  enabled: !loading,

                  keyboardType:
                  TextInputType.phone,

                  decoration: inputDecoration(
                    '+60 12-345 6789',
                    prefixIcon: const Icon(
                      Icons.phone_outlined,
                    ),
                  ),

                  validator: (value) {
                    if (value == null ||
                        value.trim().isEmpty) {
                      return 'Phone number is required.';
                    }

                    if (value.trim().length < 8) {
                      return 'Enter a valid phone number.';
                    }

                    return null;
                  },
                ),

                const SizedBox(height: 18),

                // =================================================
                // PASSWORD
                // =================================================

                const _FieldLabel(
                  'PASSWORD',
                ),

                const SizedBox(height: 8),

                TextFormField(
                  controller: passwordController,
                  enabled: !loading,

                  obscureText: obscurePassword,

                  decoration: inputDecoration(
                    '••••••••',

                    prefixIcon: const Icon(
                      Icons.lock_outline,
                    ),

                    suffixIcon: IconButton(
                      onPressed: () {
                        setState(() {
                          obscurePassword =
                          !obscurePassword;
                        });
                      },

                      icon: Icon(
                        obscurePassword
                            ? Icons.visibility
                            : Icons.visibility_off,
                      ),
                    ),
                  ),

                  validator: (value) {
                    if (value == null ||
                        value.isEmpty) {
                      return 'Password is required.';
                    }

                    if (!isStrongPassword(value)) {
                      return 'Use 8+ characters with uppercase, lowercase and number.';
                    }

                    return null;
                  },
                ),

                const SizedBox(height: 8),

                const Text(
                  'Minimum 8 characters with uppercase, lowercase and number.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                  ),
                ),

                const SizedBox(height: 18),

                // =================================================
                // CONFIRM PASSWORD
                // =================================================

                const _FieldLabel(
                  'CONFIRM PASSWORD',
                ),

                const SizedBox(height: 8),

                TextFormField(
                  controller:
                  confirmPasswordController,

                  enabled: !loading,

                  obscureText:
                  obscureConfirmPassword,

                  textInputAction:
                  TextInputAction.done,

                  decoration: inputDecoration(
                    '••••••••',

                    prefixIcon: const Icon(
                      Icons.lock_reset_outlined,
                    ),

                    suffixIcon: IconButton(
                      onPressed: () {
                        setState(() {
                          obscureConfirmPassword =
                          !obscureConfirmPassword;
                        });
                      },

                      icon: Icon(
                        obscureConfirmPassword
                            ? Icons.visibility
                            : Icons.visibility_off,
                      ),
                    ),
                  ),

                  validator: (value) {
                    if (value == null ||
                        value.isEmpty) {
                      return 'Please confirm your password.';
                    }

                    if (value !=
                        passwordController.text) {
                      return 'Passwords do not match.';
                    }

                    return null;
                  },
                ),

                const SizedBox(height: 28),

                // =================================================
                // CREATE ACCOUNT BUTTON
                // =================================================

                SizedBox(
                  width: double.infinity,
                  height: 56,

                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                      AppColors.primaryDark,

                      foregroundColor:
                      Colors.white,

                      disabledBackgroundColor:
                      AppColors.primaryDark
                          .withOpacity(
                        0.5,
                      ),

                      shape: RoundedRectangleBorder(
                        borderRadius:
                        BorderRadius.circular(
                          15,
                        ),
                      ),
                    ),

                    onPressed:
                    loading ? null : register,

                    child: loading
                        ? const SizedBox(
                      width: 22,
                      height: 22,

                      child:
                      CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                        : const Text(
                      'Create Account',

                      style: TextStyle(
                        fontSize: 17,
                        fontWeight:
                        FontWeight.bold,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 18),

                // =================================================
                // CITIZEN NOTICE
                // =================================================

                Container(
                  width: double.infinity,

                  padding: const EdgeInsets.all(
                    14,
                  ),

                  decoration: BoxDecoration(
                    color: AppColors.surface,

                    borderRadius:
                    BorderRadius.circular(
                      13,
                    ),

                    border: Border.all(
                      color: AppColors.border,
                    ),
                  ),

                  child: const Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 18,
                        color: AppColors.primary,
                      ),

                      SizedBox(width: 10),

                      Expanded(
                        child: Text(
                          'New accounts are registered as Citizen accounts. Worker and Admin roles are assigned separately.',

                          style: TextStyle(
                            color:
                            AppColors.textSecondary,

                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ================================================================
// FIELD LABEL
// ================================================================

class _FieldLabel extends StatelessWidget {
  final String text;

  const _FieldLabel(
      this.text,
      );

  @override
  Widget build(BuildContext context) {
    return Text(
      text,

      style: const TextStyle(
        color: Color(
          0xFFA9C7EF,
        ),

        fontSize: 12,

        fontWeight: FontWeight.w600,

        letterSpacing: 0.4,
      ),
    );
  }
}