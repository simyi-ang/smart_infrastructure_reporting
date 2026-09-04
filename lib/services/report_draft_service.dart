import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/report_draft.dart';

class ReportDraftService {
  ReportDraftService._();

  // ============================================================
  // SHARED PREFERENCES KEY
  // ============================================================

  static const String _draftKeyPrefix =
      'smartcity_active_report_draft';

  // ============================================================
  // LOCAL EVIDENCE DIRECTORY
  // ============================================================

  static const String _draftMediaFolder =
      'smartcity_report_drafts';

  static const String _imagesFolder =
      'images';

  static const String _videosFolder =
      'videos';

  // ============================================================
  // USER-SCOPED KEY
  // ============================================================

  static String _keyForUser(
      String userId,
      ) {
    return '${_draftKeyPrefix}_$userId';
  }

  // ============================================================
  // SAFE USER FOLDER NAME
  // ============================================================

  static String _safeUserId(
      String userId,
      ) {
    return userId.replaceAll(
      RegExp(
        r'[^A-Za-z0-9_-]',
      ),
      '_',
    );
  }

  // ============================================================
  // HAS DRAFT
  // ============================================================

  static Future<bool> hasDraft({
    required String userId,
  }) async {
    final SharedPreferences prefs =
    await SharedPreferences
        .getInstance();

    final String? raw =
    prefs.getString(
      _keyForUser(
        userId,
      ),
    );

    if (raw == null ||
        raw.trim().isEmpty) {
      return false;
    }

    try {
      final dynamic decoded =
      jsonDecode(
        raw,
      );

      if (decoded is! Map) {
        return false;
      }

      final ReportDraft draft =
      ReportDraft.fromJson(
        Map<String, dynamic>.from(
          decoded,
        ),
      );

      return draft.hasData;
    } catch (_) {
      return false;
    }
  }

  // ============================================================
  // LOAD DRAFT
  // ============================================================

  static Future<ReportDraft?> loadDraft({
    required String userId,
  }) async {
    final SharedPreferences prefs =
    await SharedPreferences
        .getInstance();

    final String? raw =
    prefs.getString(
      _keyForUser(
        userId,
      ),
    );

    if (raw == null ||
        raw.trim().isEmpty) {
      return null;
    }

    try {
      final dynamic decoded =
      jsonDecode(
        raw,
      );

      if (decoded is! Map) {
        return null;
      }

      ReportDraft draft =
      ReportDraft.fromJson(
        Map<String, dynamic>.from(
          decoded,
        ),
      );

      // ========================================================
      // CLEAN MISSING MEDIA PATHS
      //
      // For example:
      // - file manually removed
      // - old temporary picker path expired
      // - application cache was cleared
      // ========================================================

      draft =
      await _removeMissingMediaPaths(
        draft,
      );

      if (!draft.hasData) {
        return null;
      }

      return draft;
    } catch (_) {
      // Never crash Create Report because of a corrupted
      // local draft.
      return null;
    }
  }

  // ============================================================
  // SAVE DRAFT
  // ============================================================

  static Future<void> saveDraft({
    required String userId,
    required ReportDraft draft,
  }) async {
    final SharedPreferences prefs =
    await SharedPreferences
        .getInstance();

    final ReportDraft updatedDraft =
    draft.copyWith(
      updatedAt: DateTime.now(),
    );

    final String encoded =
    jsonEncode(
      updatedDraft.toJson(),
    );

    final bool success =
    await prefs.setString(
      _keyForUser(
        userId,
      ),
      encoded,
    );

    if (!success) {
      throw Exception(
        'Unable to save report draft.',
      );
    }
  }

  // ============================================================
  // UPDATE DRAFT
  //
  // Keeps backward compatibility with your existing screens.
  // ============================================================

  // ============================================================
// UPDATE DRAFT — SAFE PARTIAL UPDATE
//
// IMPORTANT:
//
// Nullable fields use Object? + sentinel.
//
// This allows us to distinguish:
//
// not supplied
//     → preserve existing value
//
// supplied null
//     → intentionally clear value
//
// This prevents Details / Evidence / Location / Preview from
// accidentally deleting one another's saved information.
// ============================================================

  static const Object _notProvided =
  Object();

  static Future<ReportDraft> updateDraft({
    required String userId,

    String? category,
    String? priority,
    String? title,
    String? description,

    Object? landmark =
        _notProvided,

    Object? manualAddress =
        _notProvided,

    Object? latitude =
        _notProvided,

    Object? longitude =
        _notProvided,

    Object? locationAccuracy =
        _notProvided,

    Object? detectedAddress =
        _notProvided,

    Object? locationVerificationStatus =
        _notProvided,

    Object? addressDistanceMeters =
        _notProvided,

    Object? voiceTranscript =
        _notProvided,

    Object? voiceLocationContext =
        _notProvided,

    Object? voiceSafetyConcern =
        _notProvided,

    int? currentStep,

    bool? hasCloseUpEvidence,

    bool? hasContextEvidence,

    List<String>? evidenceImagePaths,

    List<String>? evidenceVideoPaths,
  }) async {
    // ==========================================================
    // 1. LOAD CURRENT DRAFT
    // ==========================================================

    final ReportDraft? existing =
    await loadDraft(
      userId: userId,
    );

    final ReportDraft base =
        existing ??
            ReportDraft.empty();

    // ==========================================================
    // 2. START WITH NON-NULLABLE VALUES
    // ==========================================================

    ReportDraft updated =
    base.copyWith(
      category:
      category,

      priority:
      priority,

      title:
      title,

      description:
      description,

      currentStep:
      currentStep,

      hasCloseUpEvidence:
      hasCloseUpEvidence,

      hasContextEvidence:
      hasContextEvidence,

      evidenceImagePaths:
      evidenceImagePaths,

      evidenceVideoPaths:
      evidenceVideoPaths,

      updatedAt:
      DateTime.now(),
    );

    // ==========================================================
    // 3. LOCATION
    //
    // Only modify a field when the caller actually supplied it.
    // ==========================================================

    if (!identical(
      landmark,
      _notProvided,
    )) {
      updated =
          updated.copyWith(
            landmark:
            landmark as String?,
          );
    }

    if (!identical(
      manualAddress,
      _notProvided,
    )) {
      updated =
          updated.copyWith(
            manualAddress:
            manualAddress as String?,
          );
    }

    if (!identical(
      latitude,
      _notProvided,
    )) {
      updated =
          updated.copyWith(
            latitude:
            latitude as double?,
          );
    }

    if (!identical(
      longitude,
      _notProvided,
    )) {
      updated =
          updated.copyWith(
            longitude:
            longitude as double?,
          );
    }

    if (!identical(
      locationAccuracy,
      _notProvided,
    )) {
      updated =
          updated.copyWith(
            locationAccuracy:
            locationAccuracy
            as double?,
          );
    }

    if (!identical(
      detectedAddress,
      _notProvided,
    )) {
      updated =
          updated.copyWith(
            detectedAddress:
            detectedAddress
            as String?,
          );
    }

    if (!identical(
      locationVerificationStatus,
      _notProvided,
    )) {
      updated =
          updated.copyWith(
            locationVerificationStatus:
            locationVerificationStatus
            as String?,
          );
    }

    if (!identical(
      addressDistanceMeters,
      _notProvided,
    )) {
      updated =
          updated.copyWith(
            addressDistanceMeters:
            addressDistanceMeters
            as double?,
          );
    }

    // ==========================================================
    // 4. VOICE DATA
    // ==========================================================

    if (!identical(
      voiceTranscript,
      _notProvided,
    )) {
      updated =
          updated.copyWith(
            voiceTranscript:
            voiceTranscript
            as String?,
          );
    }

    if (!identical(
      voiceLocationContext,
      _notProvided,
    )) {
      updated =
          updated.copyWith(
            voiceLocationContext:
            voiceLocationContext
            as String?,
          );
    }

    if (!identical(
      voiceSafetyConcern,
      _notProvided,
    )) {
      updated =
          updated.copyWith(
            voiceSafetyConcern:
            voiceSafetyConcern
            as String?,
          );
    }

    // ==========================================================
    // 5. SAVE
    // ==========================================================

    await saveDraft(
      userId:
      userId,

      draft:
      updated,
    );

    return updated;
  }

  // ============================================================
  // PERSIST IMAGE
  //
  // Takes an image_picker/compressed temporary File and copies it
  // into application documents storage.
  //
  // RETURN:
  // Permanent local path.
  // ============================================================

  static Future<String> persistEvidenceImage({
    required String userId,
    required File sourceFile,
  }) async {
    if (!await sourceFile.exists()) {
      throw Exception(
        'The selected evidence image is no longer available.',
      );
    }

    final Directory directory =
    await _getEvidenceDirectory(
      userId: userId,
      evidenceType:
      _imagesFolder,
    );

    final String extension =
    _fileExtension(
      sourceFile.path,
      fallback: '.jpg',
    );

    final String fileName =
        'image_'
        '${DateTime.now().microsecondsSinceEpoch}'
        '$extension';

    final String destinationPath =
        '${directory.path}'
        '${Platform.pathSeparator}'
        '$fileName';

    final File copiedFile =
    await sourceFile.copy(
      destinationPath,
    );

    if (!await copiedFile.exists()) {
      throw Exception(
        'Unable to preserve evidence image.',
      );
    }

    await addEvidenceImage(
      userId: userId,
      imagePath:
      copiedFile.path,
    );

    return copiedFile.path;
  }

  // ============================================================
  // PERSIST VIDEO
  //
  // Copies image_picker video into application documents storage.
  //
  // RETURN:
  // Permanent local path.
  // ============================================================

  static Future<String> persistEvidenceVideo({
    required String userId,
    required File sourceFile,
  }) async {
    // ============================================================
    // 1. SOURCE MUST EXIST
    // ============================================================

    if (!await sourceFile.exists()) {
      throw Exception(
        'The selected evidence video is no longer available.',
      );
    }

    // ============================================================
    // 2. GET PERMANENT VIDEO DRAFT DIRECTORY
    // ============================================================

    final Directory directory =
    await _getEvidenceDirectory(
      userId: userId,
      evidenceType: _videosFolder,
    );

    // ============================================================
    // 3. DETERMINE EXTENSION
    // ============================================================

    final String extension =
    _fileExtension(
      sourceFile.path,
      fallback: '.mp4',
    );

    // ============================================================
    // 4. CREATE UNIQUE FILE NAME
    // ============================================================

    final String fileName =
        'video_'
        '${DateTime.now().microsecondsSinceEpoch}'
        '$extension';

    final String destinationPath =
        '${directory.path}'
        '${Platform.pathSeparator}'
        '$fileName';

    // ============================================================
    // 5. COPY CAMERA / GALLERY / COMPRESSED VIDEO
    //
    // The source may be temporary.
    // The destination is application document storage.
    // ============================================================

    final File copiedFile =
    await sourceFile.copy(
      destinationPath,
    );

    // ============================================================
    // 6. VERIFY PERMANENT FILE
    // ============================================================

    if (!await copiedFile.exists()) {
      throw Exception(
        'Unable to preserve evidence video.',
      );
    }

    final int copiedBytes =
    await copiedFile.length();

    if (copiedBytes <= 0) {
      try {
        await copiedFile.delete();
      } catch (_) {
        // Ignore cleanup failure.
      }

      throw Exception(
        'The preserved evidence video is empty.',
      );
    }

    // ============================================================
    // IMPORTANT
    //
    // DO NOT call addEvidenceVideo() here.
    //
    // The Evidence screen owns the current evidence state and will
    // save evidenceVideoPaths through _saveDraft().
    //
    // This prevents two independent SharedPreferences writes from
    // racing against each other.
    // ============================================================

    return copiedFile.path;
  }

  // ============================================================
  // ADD IMAGE PATH
  //
  // This method is retained for compatibility with existing code.
  // Prefer persistEvidenceImage() for newly selected files.
  // ============================================================

  static Future<ReportDraft> addEvidenceImage({
    required String userId,
    required String imagePath,
  }) async {
    final ReportDraft? existing =
    await loadDraft(
      userId: userId,
    );

    final ReportDraft base =
        existing ??
            ReportDraft.empty();

    final List<String> paths =
    List<String>.from(
      base.evidenceImagePaths,
    );

    if (!paths.contains(
      imagePath,
    )) {
      paths.add(
        imagePath,
      );
    }

    final ReportDraft updated =
    base.copyWith(
      evidenceImagePaths:
      paths,
      updatedAt:
      DateTime.now(),
    );

    await saveDraft(
      userId: userId,
      draft: updated,
    );

    return updated;
  }

  // ============================================================
  // ADD VIDEO PATH
  // ============================================================

  static Future<ReportDraft> addEvidenceVideo({
    required String userId,
    required String videoPath,
  }) async {
    final ReportDraft? existing =
    await loadDraft(
      userId: userId,
    );

    final ReportDraft base =
        existing ??
            ReportDraft.empty();

    final List<String> paths =
    List<String>.from(
      base.evidenceVideoPaths,
    );

    if (!paths.contains(
      videoPath,
    )) {
      paths.add(
        videoPath,
      );
    }

    final ReportDraft updated =
    base.copyWith(
      evidenceVideoPaths:
      paths,
      updatedAt:
      DateTime.now(),
    );

    await saveDraft(
      userId: userId,
      draft: updated,
    );

    return updated;
  }

  // ============================================================
  // REMOVE IMAGE
  //
  // Removes:
  // 1. path from draft JSON
  // 2. persistent local draft file
  // ============================================================

  static Future<ReportDraft> removeEvidenceImage({
    required String userId,
    required String imagePath,
    bool deleteLocalFile = true,
  }) async {
    final ReportDraft? existing =
    await loadDraft(
      userId: userId,
    );

    final ReportDraft base =
        existing ??
            ReportDraft.empty();

    final List<String> paths =
    List<String>.from(
      base.evidenceImagePaths,
    );

    paths.remove(
      imagePath,
    );

    final ReportDraft updated =
    base.copyWith(
      evidenceImagePaths:
      paths,
      updatedAt:
      DateTime.now(),
    );

    await saveDraft(
      userId: userId,
      draft: updated,
    );

    if (deleteLocalFile) {
      await _deleteDraftMediaFile(
        path: imagePath,
        userId: userId,
      );
    }

    return updated;
  }

  // ============================================================
  // REMOVE VIDEO
  // ============================================================

  static Future<ReportDraft> removeEvidenceVideo({
    required String userId,
    required String videoPath,
    bool deleteLocalFile = true,
  }) async {
    final ReportDraft? existing =
    await loadDraft(
      userId: userId,
    );

    final ReportDraft base =
        existing ??
            ReportDraft.empty();

    final List<String> paths =
    List<String>.from(
      base.evidenceVideoPaths,
    );

    paths.remove(
      videoPath,
    );

    final ReportDraft updated =
    base.copyWith(
      evidenceVideoPaths:
      paths,
      updatedAt:
      DateTime.now(),
    );

    await saveDraft(
      userId: userId,
      draft: updated,
    );

    if (deleteLocalFile) {
      await _deleteDraftMediaFile(
        path: videoPath,
        userId: userId,
      );
    }

    return updated;
  }

  // ============================================================
  // REPLACE ALL IMAGE PATHS
  // ============================================================

  static Future<ReportDraft> replaceEvidenceImages({
    required String userId,
    required List<String> imagePaths,
  }) async {
    final ReportDraft? existing =
    await loadDraft(
      userId: userId,
    );

    final ReportDraft base =
        existing ??
            ReportDraft.empty();

    final ReportDraft updated =
    base.copyWith(
      evidenceImagePaths:
      List<String>.from(
        imagePaths,
      ),
      updatedAt:
      DateTime.now(),
    );

    await saveDraft(
      userId: userId,
      draft: updated,
    );

    return updated;
  }

  // ============================================================
  // REPLACE ALL VIDEO PATHS
  // ============================================================

  static Future<ReportDraft> replaceEvidenceVideos({
    required String userId,
    required List<String> videoPaths,
  }) async {
    final ReportDraft? existing =
    await loadDraft(
      userId: userId,
    );

    final ReportDraft base =
        existing ??
            ReportDraft.empty();

    final ReportDraft updated =
    base.copyWith(
      evidenceVideoPaths:
      List<String>.from(
        videoPaths,
      ),
      updatedAt:
      DateTime.now(),
    );

    await saveDraft(
      userId: userId,
      draft: updated,
    );

    return updated;
  }

  // ============================================================
  // CLEAR EVIDENCE ONLY
  //
  // Useful if user wants to replace evidence but keep Details.
  // ============================================================

  static Future<ReportDraft> clearEvidence({
    required String userId,
  }) async {
    final ReportDraft? existing =
    await loadDraft(
      userId: userId,
    );

    final ReportDraft base =
        existing ??
            ReportDraft.empty();

    await _deleteUserDraftMediaDirectory(
      userId,
    );

    final ReportDraft updated =
    base.copyWith(
      evidenceImagePaths:
      <String>[],
      evidenceVideoPaths:
      <String>[],
      hasCloseUpEvidence:
      false,
      hasContextEvidence:
      false,
      updatedAt:
      DateTime.now(),
    );

    await saveDraft(
      userId: userId,
      draft: updated,
    );

    return updated;
  }

  // ============================================================
  // CLEAR COMPLETE DRAFT
  //
  // ONLY USE WHEN:
  //
  // 1. Citizen explicitly discards report
  // OR
  // 2. Report submission succeeds
  //
  // It also deletes persistent local draft evidence.
  // ============================================================

  static Future<void> clearDraft({
    required String userId,
  }) async {
    final SharedPreferences prefs =
    await SharedPreferences
        .getInstance();

    await prefs.remove(
      _keyForUser(
        userId,
      ),
    );

    await _deleteUserDraftMediaDirectory(
      userId,
    );
  }

  // ============================================================
  // LAST UPDATED
  // ============================================================

  static Future<DateTime?> getLastUpdated({
    required String userId,
  }) async {
    final ReportDraft? draft =
    await loadDraft(
      userId: userId,
    );

    return draft?.updatedAt;
  }

  // ============================================================
  // TOTAL EVIDENCE COUNT
  // ============================================================

  static Future<int> getEvidenceCount({
    required String userId,
  }) async {
    final ReportDraft? draft =
    await loadDraft(
      userId: userId,
    );

    if (draft == null) {
      return 0;
    }

    return draft.totalEvidenceCount;
  }

  // ============================================================
  // GET DRAFT ROOT DIRECTORY
  // ============================================================

  static Future<Directory> _getUserDraftDirectory(
      String userId,
      ) async {
    final Directory documents =
    await getApplicationDocumentsDirectory();

    final String safeUser =
    _safeUserId(
      userId,
    );

    final String path =
        '${documents.path}'
        '${Platform.pathSeparator}'
        '$_draftMediaFolder'
        '${Platform.pathSeparator}'
        '$safeUser';

    final Directory directory =
    Directory(
      path,
    );

    if (!await directory.exists()) {
      await directory.create(
        recursive: true,
      );
    }

    return directory;
  }

  // ============================================================
  // GET IMAGE / VIDEO DIRECTORY
  // ============================================================

  static Future<Directory> _getEvidenceDirectory({
    required String userId,
    required String evidenceType,
  }) async {
    final Directory userDirectory =
    await _getUserDraftDirectory(
      userId,
    );

    final String path =
        '${userDirectory.path}'
        '${Platform.pathSeparator}'
        '$evidenceType';

    final Directory directory =
    Directory(
      path,
    );

    if (!await directory.exists()) {
      await directory.create(
        recursive: true,
      );
    }

    return directory;
  }

  // ============================================================
  // REMOVE MISSING MEDIA PATHS
  // ============================================================

  static Future<ReportDraft>
  _removeMissingMediaPaths(
      ReportDraft draft,
      ) async {
    final List<String> validImages =
    <String>[];

    for (final String path
    in draft.evidenceImagePaths) {
      try {
        if (await File(path).exists()) {
          validImages.add(
            path,
          );
        }
      } catch (_) {
        // Ignore invalid path.
      }
    }

    final List<String> validVideos =
    <String>[];

    for (final String path
    in draft.evidenceVideoPaths) {
      try {
        if (await File(path).exists()) {
          validVideos.add(
            path,
          );
        }
      } catch (_) {
        // Ignore invalid path.
      }
    }

    if (validImages.length ==
        draft
            .evidenceImagePaths.length &&
        validVideos.length ==
            draft
                .evidenceVideoPaths.length) {
      return draft;
    }

    return draft.copyWith(
      evidenceImagePaths:
      validImages,
      evidenceVideoPaths:
      validVideos,
      updatedAt:
      DateTime.now(),
    );
  }

  // ============================================================
  // DELETE ONE DRAFT MEDIA FILE SAFELY
  //
  // Only files inside SmartCity's draft media directory
  // are deleted.
  //
  // This prevents accidentally deleting a user's original
  // gallery file.
  // ============================================================

  static Future<void> _deleteDraftMediaFile({
    required String path,
    required String userId,
  }) async {
    try {
      final Directory userDirectory =
      await _getUserDraftDirectory(
        userId,
      );

      final String userRoot =
          userDirectory.absolute.path;

      final File file =
      File(
        path,
      );

      final String filePath =
          file.absolute.path;

      if (!filePath.startsWith(
        userRoot,
      )) {
        // Never delete files outside the SmartCity
        // draft directory.
        return;
      }

      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {
      // File cleanup should never crash report creation.
    }
  }

  // ============================================================
  // DELETE ALL DRAFT MEDIA FOR USER
  // ============================================================

  static Future<void>
  _deleteUserDraftMediaDirectory(
      String userId,
      ) async {
    try {
      final Directory documents =
      await getApplicationDocumentsDirectory();

      final String safeUser =
      _safeUserId(
        userId,
      );

      final String path =
          '${documents.path}'
          '${Platform.pathSeparator}'
          '$_draftMediaFolder'
          '${Platform.pathSeparator}'
          '$safeUser';

      final Directory directory =
      Directory(
        path,
      );

      if (await directory.exists()) {
        await directory.delete(
          recursive: true,
        );
      }
    } catch (_) {
      // Draft cleanup should never crash logout/discard/submit.
    }
  }

  // ============================================================
  // FILE EXTENSION
  // ============================================================

  static String _fileExtension(
      String path, {
        required String fallback,
      }) {
    final String fileName =
        path
            .replaceAll(
          '\\',
          '/',
        )
            .split('/')
            .last;

    final int dotIndex =
    fileName.lastIndexOf(
      '.',
    );

    if (dotIndex <= 0 ||
        dotIndex ==
            fileName.length - 1) {
      return fallback;
    }

    final String extension =
    fileName
        .substring(
      dotIndex,
    )
        .toLowerCase();

    // Avoid unreasonable / corrupted extensions.
    if (extension.length > 10) {
      return fallback;
    }

    return extension;
  }
}