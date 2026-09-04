import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/community_report.dart';
import '../../services/community_service.dart';
import '../../theme/app_colors.dart';

// ============================================================================
// COMMUNITY REPORT DETAIL SCREEN — DYNAMIC ADVANCED VERSION
//
// Main improvements:
//
// 1. Automatic live refresh every 12 seconds.
// 2. Refreshes immediately when the app returns from background.
// 3. Progress/status changes made by workers become visible automatically.
// 4. Dynamic progress phase + milestone timeline.
// 5. Community Impact Intelligence panel.
// 6. Dynamic "Still Exists" / "Looks Fixed" consensus.
// 7. Safer optimistic actions with automatic server refresh.
// 8. Community evidence contribution remains supported.
// 9. Friendly empty/loading/error states.
// 10. Existing CommunityService + CommunityReport architecture is preserved.
//
// IMPORTANT:
// Community activity NEVER silently changes official worker status/priority.
// ============================================================================

class CommunityReportDetailScreen extends StatefulWidget {
  final String reportId;
  final double? currentLatitude;
  final double? currentLongitude;

  const CommunityReportDetailScreen({
    super.key,
    required this.reportId,
    this.currentLatitude,
    this.currentLongitude,
  });

  @override
  State<CommunityReportDetailScreen> createState() =>
      _CommunityReportDetailScreenState();
}

class _CommunityReportDetailScreenState
    extends State<CommunityReportDetailScreen>
    with WidgetsBindingObserver {
  final CommunityService service =
      CommunityService.instance;

  final ImagePicker picker =
  ImagePicker();

  CommunityReport? report;

  List<CommunityContribution> contributions =
  <CommunityContribution>[];

  bool loading =
  true;

  bool refreshing =
  false;

  bool updating =
  false;

  bool addingEvidence =
  false;

  String? error;

  bool changed =
  false;

  Timer? liveRefreshTimer;

  DateTime? lastSyncedAt;

  int liveRefreshSeconds =
  12;

  // ==========================================================================
  // INIT / LIFECYCLE
  // ==========================================================================

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(
      this,
    );

    _load();

    liveRefreshTimer =
        Timer.periodic(
          Duration(
            seconds:
            liveRefreshSeconds,
          ),
              (
              timer,
              ) async {
            if (!mounted ||
                loading ||
                refreshing ||
                updating ||
                addingEvidence) {
              return;
            }

            await _refreshSilently();
          },
        );
  }

  @override
  void dispose() {
    liveRefreshTimer?.cancel();

    WidgetsBinding.instance.removeObserver(
      this,
    );

    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(
      AppLifecycleState state,
      ) {
    if (state ==
        AppLifecycleState.resumed) {
      _refreshSilently();
    }
  }

  // ==========================================================================
  // INITIAL LOAD
  // ==========================================================================

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        loading =
        true;

        error =
        null;
      });
    }

    try {
      final CommunityReport loaded =
      await service.getReportDetail(
        reportId:
        widget.reportId,
        latitude:
        widget.currentLatitude,
        longitude:
        widget.currentLongitude,
      );

      final List<CommunityContribution> evidence =
      await service.getContributions(
        reportId:
        widget.reportId,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        report =
            loaded;

        contributions =
            evidence;

        loading =
        false;

        lastSyncedAt =
            DateTime.now();
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        loading =
        false;

        error =
            _cleanError(
              e,
            );
      });
    }
  }

  // ==========================================================================
  // SILENT LIVE REFRESH
  //
  // Worker changes:
  // status
  // progress
  // priority
  // title
  // description
  //
  // Community changes:
  // affected count
  // feedback counts
  // contribution count
  //
  // all become visible without leaving/reopening the screen.
  // ==========================================================================

  Future<void> _refreshSilently({
    bool showIndicator = false,
  }) async {
    if (refreshing) {
      return;
    }

    if (mounted) {
      setState(() {
        refreshing =
        true;
      });
    }

    try {
      final CommunityReport latest =
      await service.getReportDetail(
        reportId:
        widget.reportId,
        latitude:
        widget.currentLatitude,
        longitude:
        widget.currentLongitude,
      );

      final List<CommunityContribution> latestEvidence =
      await service.getContributions(
        reportId:
        widget.reportId,
      );

      if (!mounted) {
        return;
      }

      final CommunityReport? previous =
          report;

      final bool progressChanged =
          previous != null &&
              (previous.progressPercentage !=
                  latest.progressPercentage ||
                  previous.status !=
                      latest.status);

      setState(() {
        report =
            latest;

        contributions =
            latestEvidence;

        lastSyncedAt =
            DateTime.now();

        refreshing =
        false;
      });

      if (progressChanged &&
          showIndicator) {
        _message(
          'Report progress updated to '
              '${latest.progressPercentage}% · ${latest.status}.',
        );
      }
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        refreshing =
        false;
      });

      if (showIndicator) {
        _message(
          _cleanError(
            e,
          ),
        );
      }
    }
  }

  // ==========================================================================
  // COMMUNITY AFFECTED TOGGLE
  // ==========================================================================

  Future<void> _toggleAffected() async {
    final CommunityReport? current =
        report;

    if (current ==
        null ||
        updating) {
      return;
    }

    setState(() {
      updating =
      true;
    });

    try {
      final CommunityReport updated =
      await service.setAffected(
        report:
        current,
        affected:
        !current.userAffected,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        report =
            updated;

        changed =
        true;
      });

      await _refreshSilently();
    } catch (e) {
      _message(
        _cleanError(
          e,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          updating =
          false;
        });
      }
    }
  }

  // ==========================================================================
  // COMMUNITY OBSERVATION
  // ==========================================================================

  Future<void> _setFeedback(
      String feedback,
      ) async {
    final CommunityReport? current =
        report;

    if (current ==
        null ||
        updating) {
      return;
    }

    setState(() {
      updating =
      true;
    });

    try {
      final CommunityReport updated =
      await service.setFeedback(
        report:
        current,
        feedback:
        current.userFeedback ==
            feedback
            ? null
            : feedback,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        report =
            updated;

        changed =
        true;
      });

      await _refreshSilently();
    } catch (e) {
      _message(
        _cleanError(
          e,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          updating =
          false;
        });
      }
    }
  }

  // ==========================================================================
  // ADD COMMUNITY EVIDENCE
  // ==========================================================================

  Future<void> _addEvidence() async {
    if (addingEvidence) {
      return;
    }

    final String? choice =
    await showModalBottomSheet<String>(
      context:
      context,
      backgroundColor:
      AppColors.surface,
      showDragHandle:
      true,
      builder:
          (
          sheetContext,
          ) {
        return SafeArea(
          child:
          Padding(
            padding:
            const EdgeInsets.fromLTRB(
              16,
              2,
              16,
              16,
            ),
            child:
            Column(
              mainAxisSize:
              MainAxisSize.min,
              children: [
                const Text(
                  'Contribute Evidence',
                  style:
                  TextStyle(
                    color:
                    Colors.white,
                    fontSize:
                    16,
                    fontWeight:
                    FontWeight.w700,
                  ),
                ),

                const SizedBox(
                  height:
                  5,
                ),

                const Text(
                  'Add only evidence that shows this exact issue.',
                  style:
                  TextStyle(
                    color:
                    AppColors.textSecondary,
                    fontSize:
                    9,
                  ),
                ),

                const SizedBox(
                  height:
                  10,
                ),

                ListTile(
                  leading:
                  const Icon(
                    Icons.camera_alt_outlined,
                    color:
                    AppColors.primary,
                  ),
                  title:
                  const Text(
                    'Take Photo',
                  ),
                  subtitle:
                  const Text(
                    'Capture current condition',
                  ),
                  onTap:
                      () =>
                      Navigator.pop(
                        sheetContext,
                        'camera_image',
                      ),
                ),

                ListTile(
                  leading:
                  const Icon(
                    Icons.photo_library_outlined,
                    color:
                    AppColors.primary,
                  ),
                  title:
                  const Text(
                    'Choose Photo',
                  ),
                  onTap:
                      () =>
                      Navigator.pop(
                        sheetContext,
                        'gallery_image',
                      ),
                ),

                ListTile(
                  leading:
                  const Icon(
                    Icons.videocam_outlined,
                    color:
                    AppColors.primary,
                  ),
                  title:
                  const Text(
                    'Record Short Video',
                  ),
                  subtitle:
                  const Text(
                    'Maximum 30 seconds',
                  ),
                  onTap:
                      () =>
                      Navigator.pop(
                        sheetContext,
                        'camera_video',
                      ),
                ),

                ListTile(
                  leading:
                  const Icon(
                    Icons.video_library_outlined,
                    color:
                    AppColors.primary,
                  ),
                  title:
                  const Text(
                    'Choose Short Video',
                  ),
                  onTap:
                      () =>
                      Navigator.pop(
                        sheetContext,
                        'gallery_video',
                      ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (choice ==
        null) {
      return;
    }

    final bool isImage =
    choice.endsWith(
      'image',
    );

    final ImageSource source =
    choice.startsWith(
      'camera',
    )
        ? ImageSource.camera
        : ImageSource.gallery;

    XFile? picked;

    if (isImage) {
      picked =
      await picker.pickImage(
        source:
        source,
        imageQuality:
        85,
        maxWidth:
        1920,
      );
    } else {
      picked =
      await picker.pickVideo(
        source:
        source,
        maxDuration:
        const Duration(
          seconds:
          30,
        ),
      );
    }

    if (picked ==
        null) {
      return;
    }

    final String? note =
    await _askNote();

    if (note ==
        null) {
      return;
    }

    setState(() {
      addingEvidence =
      true;
    });

    try {
      await service.addContribution(
        reportId:
        widget.reportId,
        file:
        File(
          picked.path,
        ),
        evidenceType:
        isImage
            ? 'image'
            : 'video',
        note:
        note,
      );

      if (!mounted) {
        return;
      }

      changed =
      true;

      await _refreshSilently();

      _message(
        'Community evidence added successfully.',
      );
    } catch (e) {
      _message(
        _cleanError(
          e,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          addingEvidence =
          false;
        });
      }
    }
  }

  // ==========================================================================
  // SAFE NOTE DIALOG
  // ==========================================================================

  Future<String?> _askNote() async {
    String note =
        '';

    final String? result =
    await showDialog<String>(
      context:
      context,
      barrierDismissible:
      false,
      builder:
          (
          dialogContext,
          ) {
        return AlertDialog(
          backgroundColor:
          AppColors.surface,
          title:
          const Text(
            'Evidence Description',
          ),
          content:
          TextFormField(
            initialValue:
            '',
            autofocus:
            true,
            maxLength:
            250,
            minLines:
            3,
            maxLines:
            5,
            textCapitalization:
            TextCapitalization.sentences,
            textInputAction:
            TextInputAction.newline,
            onChanged:
                (
                value,
                ) {
              note =
                  value;
            },
            decoration:
            const InputDecoration(
              hintText:
              'Optional: describe what this photo or video shows now.',
            ),
          ),
          actions: [
            TextButton(
              onPressed:
                  () {
                FocusScope.of(
                  dialogContext,
                ).unfocus();

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
              onPressed:
                  () {
                FocusScope.of(
                  dialogContext,
                ).unfocus();

                Navigator.pop(
                  dialogContext,
                  note.trim(),
                );
              },
              child:
              const Text(
                'Add Evidence',
              ),
            ),
          ],
        );
      },
    );

    return result;
  }

  // ==========================================================================
  // REMOVE OWN COMMUNITY CONTRIBUTION
  // ==========================================================================

  Future<void> _removeContribution(
      CommunityContribution contribution,
      ) async {
    if (!contribution.isMine) {
      return;
    }

    final bool? confirmed =
    await showDialog<bool>(
      context:
      context,
      builder:
          (
          dialogContext,
          ) {
        return AlertDialog(
          backgroundColor:
          AppColors.surface,
          title:
          const Text(
            'Remove Contribution?',
          ),
          content:
          const Text(
            'This community evidence will be permanently removed.',
            style:
            TextStyle(
              color:
              AppColors.textSecondary,
            ),
          ),
          actions: [
            TextButton(
              onPressed:
                  () =>
                  Navigator.pop(
                    dialogContext,
                    false,
                  ),
              child:
              const Text(
                'Keep',
              ),
            ),
            TextButton(
              onPressed:
                  () =>
                  Navigator.pop(
                    dialogContext,
                    true,
                  ),
              child:
              const Text(
                'Remove',
              ),
            ),
          ],
        );
      },
    );

    if (confirmed !=
        true) {
      return;
    }

    try {
      await service.deleteContribution(
        contribution,
      );

      if (!mounted) {
        return;
      }

      changed =
      true;

      await _refreshSilently();

      _message(
        'Community evidence removed.',
      );
    } catch (e) {
      _message(
        _cleanError(
          e,
        ),
      );
    }
  }

  // ==========================================================================
  // DYNAMIC PROGRESS INTELLIGENCE
  // ==========================================================================

  int get _progress {
    return (report?.progressPercentage ??
        0)
        .clamp(
      0,
      100,
    )
        .toInt();
  }

  String get _progressPhase {
    final String status =
        report?.status
            .trim()
            .toLowerCase() ??
            '';

    if (status ==
        'resolved' ||
        status ==
            'completed' ||
        _progress >=
            100) {
      return 'Resolved';
    }

    if (_progress >=
        75) {
      return 'Final Work & Verification';
    }

    if (_progress >=
        40) {
      return 'Repair In Progress';
    }

    if (_progress >=
        15) {
      return 'Assessment & Assignment';
    }

    return 'Reported & Awaiting Review';
  }

  IconData get _progressIcon {
    if (_progress >=
        100) {
      return Icons.verified_rounded;
    }

    if (_progress >=
        75) {
      return Icons.fact_check_outlined;
    }

    if (_progress >=
        40) {
      return Icons.handyman_outlined;
    }

    if (_progress >=
        15) {
      return Icons.assignment_ind_outlined;
    }

    return Icons.receipt_long_outlined;
  }

  String get _progressMessage {
    if (_progress >=
        100) {
      return 'Official work is marked complete. Community members can still confirm whether the issue looks fixed.';
    }

    if (_progress >=
        75) {
      return 'Work is nearing completion and may be undergoing final checks.';
    }

    if (_progress >=
        40) {
      return 'The issue is actively being worked on.';
    }

    if (_progress >=
        15) {
      return 'The issue has moved beyond initial reporting and is being assessed or assigned.';
    }

    return 'The report has been submitted and is waiting for the next official action.';
  }

  // ==========================================================================
  // COMMUNITY INTELLIGENCE
  // ==========================================================================

  double get _communityResolutionConfidence {
    final CommunityReport? current =
        report;

    if (current ==
        null) {
      return 0;
    }

    final int stillExists =
        current.stillExistsCount;

    final int looksFixed =
        current.looksFixedCount;

    final int total =
        stillExists +
            looksFixed;

    if (total ==
        0) {
      return 0;
    }

    return looksFixed /
        total;
  }

  String get _communityPulseLabel {
    final CommunityReport? current =
        report;

    if (current ==
        null) {
      return 'No community signal';
    }

    final int stillExists =
        current.stillExistsCount;

    final int fixed =
        current.looksFixedCount;

    if (stillExists ==
        0 &&
        fixed ==
            0) {
      return 'Waiting for community confirmation';
    }

    if (stillExists >
        fixed * 2) {
      return 'Community strongly reports the issue still exists';
    }

    if (fixed >
        stillExists * 2) {
      return 'Community increasingly reports that the issue looks fixed';
    }

    return 'Community observations are mixed';
  }

  String get _impactLevel {
    final double score =
        report?.impactScore ??
            0;

    if (score >=
        50) {
      return 'High Community Impact';
    }

    if (score >=
        20) {
      return 'Moderate Community Impact';
    }

    return 'Emerging Community Impact';
  }

  String get _syncLabel {
    final DateTime? synced =
        lastSyncedAt;

    if (synced ==
        null) {
      return 'Not synced yet';
    }

    final Duration difference =
    DateTime.now().difference(
      synced,
    );

    if (difference.inSeconds <
        15) {
      return 'Live · just updated';
    }

    if (difference.inMinutes <
        1) {
      return 'Updated ${difference.inSeconds}s ago';
    }

    return 'Updated ${difference.inMinutes}m ago';
  }

  // ==========================================================================
  // MESSAGE / ERROR
  // ==========================================================================

  String _cleanError(
      Object error,
      ) {
    return error
        .toString()
        .replaceFirst(
      'Exception: ',
      '',
    )
        .trim();
  }

  void _message(
      String message,
      ) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    )
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content:
          Text(
            message,
          ),
        ),
      );
  }

  // ==========================================================================
  // BUILD
  // ==========================================================================

  @override
  Widget build(
      BuildContext context,
      ) {
    if (loading) {
      return const Scaffold(
        backgroundColor:
        AppColors.background,
        body:
        _FriendlyLoadingState(),
      );
    }

    if (error !=
        null) {
      return Scaffold(
        backgroundColor:
        AppColors.background,
        appBar:
        AppBar(
          backgroundColor:
          AppColors.background,
        ),
        body:
        _FriendlyErrorState(
          message:
          error!,
          onRetry:
          _load,
        ),
      );
    }

    final CommunityReport current =
    report!;

    return WillPopScope(
      onWillPop:
          () async {
        Navigator.pop(
          context,
          changed,
        );

        return false;
      },
      child:
      Scaffold(
        backgroundColor:
        AppColors.background,
        body:
        SafeArea(
          child:
          RefreshIndicator(
            onRefresh:
                () =>
                _refreshSilently(
                  showIndicator:
                  true,
                ),
            child:
            CustomScrollView(
              physics:
              const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child:
                  Padding(
                    padding:
                    const EdgeInsets.fromLTRB(
                      20,
                      16,
                      20,
                      30,
                    ),
                    child:
                    Column(
                      crossAxisAlignment:
                      CrossAxisAlignment.start,
                      children: [
                        // =====================================================
                        // HEADER
                        // =====================================================

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
                                    () =>
                                    Navigator.pop(
                                      context,
                                      changed,
                                    ),
                                icon:
                                const Icon(
                                  Icons.arrow_back,
                                ),
                              ),
                            ),

                            const SizedBox(
                              width:
                              10,
                            ),

                            const Expanded(
                              child:
                              Column(
                                crossAxisAlignment:
                                CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Community Issue',
                                    style:
                                    TextStyle(
                                      color:
                                      Colors.white,
                                      fontSize:
                                      20,
                                      fontWeight:
                                      FontWeight.w800,
                                    ),
                                  ),
                                  Text(
                                    'Live infrastructure activity',
                                    style:
                                    TextStyle(
                                      color:
                                      AppColors.textSecondary,
                                      fontSize:
                                      9,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            _LiveSyncBadge(
                              refreshing:
                              refreshing,
                              label:
                              _syncLabel,
                              onTap:
                                  () =>
                                  _refreshSilently(
                                    showIndicator:
                                    true,
                                  ),
                            ),
                          ],
                        ),

                        const SizedBox(
                          height:
                          15,
                        ),

                        // =====================================================
                        // HERO / REPORT SUMMARY
                        // =====================================================

                        _HeroReportCard(
                          report:
                          current,
                          phase:
                          _progressPhase,
                        ),

                        const SizedBox(
                          height:
                          14,
                        ),

                        // =====================================================
                        // DYNAMIC OFFICIAL PROGRESS
                        // =====================================================

                        _DynamicProgressCard(
                          progress:
                          _progress,
                          phase:
                          _progressPhase,
                          icon:
                          _progressIcon,
                          message:
                          _progressMessage,
                          status:
                          current.status,
                        ),

                        const SizedBox(
                          height:
                          14,
                        ),

                        // =====================================================
                        // COMMUNITY IMPACT INTELLIGENCE
                        // =====================================================

                        _CommunityIntelligenceCard(
                          impactScore:
                          current.impactScore,
                          impactLevel:
                          _impactLevel,
                          affectedCount:
                          current.affectedCount,
                          stillExistsCount:
                          current.stillExistsCount,
                          looksFixedCount:
                          current.looksFixedCount,
                          contributionCount:
                          current.contributionCount,
                          communityPulse:
                          _communityPulseLabel,
                          resolutionConfidence:
                          _communityResolutionConfidence,
                        ),

                        const SizedBox(
                          height:
                          14,
                        ),

                        // =====================================================
                        // I'M AFFECTED TOO
                        // =====================================================

                        _ActionSectionCard(
                          title:
                          'Are You Affected?',
                          subtitle:
                          'Confirm that this issue affects you or your area.',
                          icon:
                          Icons.groups_2_outlined,
                          child:
                          Column(
                            children: [
                              SizedBox(
                                width:
                                double.infinity,
                                child:
                                ElevatedButton.icon(
                                  onPressed:
                                  updating
                                      ? null
                                      : _toggleAffected,
                                  icon:
                                  updating
                                      ? const SizedBox(
                                    width:
                                    16,
                                    height:
                                    16,
                                    child:
                                    CircularProgressIndicator(
                                      strokeWidth:
                                      2,
                                    ),
                                  )
                                      : Icon(
                                    current.userAffected
                                        ? Icons.check_circle
                                        : Icons.group_add_outlined,
                                  ),
                                  label:
                                  Text(
                                    current.userAffected
                                        ? 'Affected Confirmation Added'
                                        : 'I’m Affected Too',
                                  ),
                                ),
                              ),

                              const SizedBox(
                                height:
                                8,
                              ),

                              const Text(
                                'This increases the community impact signal only. '
                                    'It does not automatically change the official priority.',
                                style:
                                TextStyle(
                                  color:
                                  AppColors.textSecondary,
                                  fontSize:
                                  8,
                                  height:
                                  1.4,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(
                          height:
                          14,
                        ),

                        // =====================================================
                        // COMMUNITY CURRENT CONDITION
                        // =====================================================

                        _ActionSectionCard(
                          title:
                          'What Can You See Now?',
                          subtitle:
                          'Your latest observation replaces your previous choice.',
                          icon:
                          Icons.visibility_outlined,
                          child:
                          Row(
                            children: [
                              Expanded(
                                child:
                                _FeedbackButton(
                                  selected:
                                  current.userFeedback ==
                                      'still_exists',
                                  icon:
                                  Icons.warning_amber_rounded,
                                  label:
                                  'Still Exists',
                                  onPressed:
                                  updating
                                      ? null
                                      : () =>
                                      _setFeedback(
                                        'still_exists',
                                      ),
                                ),
                              ),

                              const SizedBox(
                                width:
                                9,
                              ),

                              Expanded(
                                child:
                                _FeedbackButton(
                                  selected:
                                  current.userFeedback ==
                                      'looks_fixed',
                                  icon:
                                  Icons.task_alt_rounded,
                                  label:
                                  'Looks Fixed',
                                  onPressed:
                                  updating
                                      ? null
                                      : () =>
                                      _setFeedback(
                                        'looks_fixed',
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

                        // =====================================================
                        // COMMUNITY EVIDENCE
                        // =====================================================

                        _ActionSectionCard(
                          title:
                          'Community Evidence',
                          subtitle:
                          '${contributions.length} supporting item(s) · '
                              'contributor identity remains private',
                          icon:
                          Icons.collections_outlined,
                          trailing:
                          TextButton.icon(
                            onPressed:
                            addingEvidence
                                ? null
                                : _addEvidence,
                            icon:
                            const Icon(
                              Icons.add,
                            ),
                            label:
                            const Text(
                              'Add',
                            ),
                          ),
                          child:
                          Column(
                            children: [
                              if (addingEvidence)
                                const Padding(
                                  padding:
                                  EdgeInsets.only(
                                    bottom:
                                    12,
                                  ),
                                  child:
                                  LinearProgressIndicator(),
                                ),

                              if (contributions.isEmpty)
                                const _EmptyEvidenceState()
                              else
                                ListView.separated(
                                  shrinkWrap:
                                  true,
                                  physics:
                                  const NeverScrollableScrollPhysics(),
                                  itemCount:
                                  contributions.length,
                                  separatorBuilder:
                                      (
                                      context,
                                      index,
                                      ) =>
                                  const SizedBox(
                                    height:
                                    10,
                                  ),
                                  itemBuilder:
                                      (
                                      context,
                                      index,
                                      ) {
                                    final CommunityContribution item =
                                    contributions[index];

                                    return _EvidenceCard(
                                      item:
                                      item,
                                      index:
                                      index,
                                      onRemove:
                                      item.isMine
                                          ? () =>
                                          _removeContribution(
                                            item,
                                          )
                                          : null,
                                    );
                                  },
                                ),
                            ],
                          ),
                        ),

                        const SizedBox(
                          height:
                          14,
                        ),

                        // =====================================================
                        // TRUST / SAFETY NOTE
                        // =====================================================

                        const _CommunityTrustCard(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// HERO REPORT CARD
// ============================================================================

class _HeroReportCard
    extends StatelessWidget {
  final CommunityReport report;
  final String phase;

  const _HeroReportCard({
    required this.report,
    required this.phase,
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
        16,
      ),
      decoration:
      BoxDecoration(
        color:
        AppColors.surface,
        borderRadius:
        BorderRadius.circular(
          18,
        ),
        border:
        Border.all(
          color:
          AppColors.primary.withOpacity(
            0.35,
          ),
        ),
      ),
      child:
      Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: [
              Expanded(
                child:
                Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Text(
                      report.title,
                      style:
                      const TextStyle(
                        color:
                        Colors.white,
                        fontSize:
                        18,
                        fontWeight:
                        FontWeight.w800,
                        height:
                        1.25,
                      ),
                    ),

                    const SizedBox(
                      height:
                      5,
                    ),

                    Text(
                      report.referenceNumber,
                      style:
                      const TextStyle(
                        color:
                        AppColors.textSecondary,
                        fontSize:
                        9,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(
                width:
                10,
              ),

              _StatusPill(
                status:
                report.status,
              ),
            ],
          ),

          const SizedBox(
            height:
            13,
          ),

          Wrap(
            spacing:
            7,
            runSpacing:
            7,
            children: [
              _InfoPill(
                icon:
                Icons.category_outlined,
                text:
                report.category,
              ),

              _InfoPill(
                icon:
                Icons.flag_outlined,
                text:
                report.priority,
              ),

              _InfoPill(
                icon:
                Icons.place_outlined,
                text:
                report.distanceLabel,
              ),

              _InfoPill(
                icon:
                Icons.route_outlined,
                text:
                phase,
              ),
            ],
          ),

          const SizedBox(
            height:
            14,
          ),

          if ((report.description ??
              '')
              .trim()
              .isNotEmpty)
            Text(
              report.description!,
              style:
              const TextStyle(
                color:
                AppColors.textSecondary,
                fontSize:
                10,
                height:
                1.5,
              ),
            ),

          const SizedBox(
            height:
            13,
          ),

          Row(
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.location_on_outlined,
                color:
                AppColors.primary,
                size:
                18,
              ),

              const SizedBox(
                width:
                7,
              ),

              Expanded(
                child:
                Text(
                  report.address,
                  style:
                  const TextStyle(
                    color:
                    Colors.white,
                    fontSize:
                    10,
                    height:
                    1.35,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// DYNAMIC PROGRESS CARD
// ============================================================================

class _DynamicProgressCard
    extends StatelessWidget {
  final int progress;
  final String phase;
  final IconData icon;
  final String message;
  final String status;

  const _DynamicProgressCard({
    required this.progress,
    required this.phase,
    required this.icon,
    required this.message,
    required this.status,
  });

  bool _reached(
      int threshold,
      ) {
    return progress >=
        threshold;
  }

  @override
  Widget build(
      BuildContext context,
      ) {
    return Container(
      width:
      double.infinity,
      padding:
      const EdgeInsets.all(
        16,
      ),
      decoration:
      BoxDecoration(
        color:
        const Color(
          0xFF082B37,
        ),
        borderRadius:
        BorderRadius.circular(
          18,
        ),
        border:
        Border.all(
          color:
          AppColors.primary.withOpacity(
            0.45,
          ),
        ),
      ),
      child:
      Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width:
                42,
                height:
                42,
                decoration:
                BoxDecoration(
                  color:
                  AppColors.primary.withOpacity(
                    0.10,
                  ),
                  borderRadius:
                  BorderRadius.circular(
                    12,
                  ),
                ),
                child:
                Icon(
                  icon,
                  color:
                  AppColors.primary,
                ),
              ),

              const SizedBox(
                width:
                11,
              ),

              Expanded(
                child:
                Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Official Progress',
                      style:
                      TextStyle(
                        color:
                        AppColors.textSecondary,
                        fontSize:
                        9,
                      ),
                    ),

                    Text(
                      phase,
                      style:
                      const TextStyle(
                        color:
                        Colors.white,
                        fontSize:
                        13,
                        fontWeight:
                        FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),

              Text(
                '$progress%',
                style:
                const TextStyle(
                  color:
                  AppColors.primary,
                  fontSize:
                  24,
                  fontWeight:
                  FontWeight.w800,
                ),
              ),
            ],
          ),

          const SizedBox(
            height:
            14,
          ),

          ClipRRect(
            borderRadius:
            BorderRadius.circular(
              20,
            ),
            child:
            LinearProgressIndicator(
              minHeight:
              8,
              value:
              progress /
                  100,
              backgroundColor:
              AppColors.border,
            ),
          ),

          const SizedBox(
            height:
            10,
          ),

          Text(
            message,
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

          const SizedBox(
            height:
            15,
          ),

          Row(
            children: [
              Expanded(
                child:
                _ProgressMilestone(
                  reached:
                  _reached(
                    0,
                  ),
                  icon:
                  Icons.send_outlined,
                  label:
                  'Reported',
                ),
              ),

              Expanded(
                child:
                _ProgressMilestone(
                  reached:
                  _reached(
                    15,
                  ),
                  icon:
                  Icons.assignment_ind_outlined,
                  label:
                  'Reviewed',
                ),
              ),

              Expanded(
                child:
                _ProgressMilestone(
                  reached:
                  _reached(
                    40,
                  ),
                  icon:
                  Icons.handyman_outlined,
                  label:
                  'Working',
                ),
              ),

              Expanded(
                child:
                _ProgressMilestone(
                  reached:
                  _reached(
                    75,
                  ),
                  icon:
                  Icons.fact_check_outlined,
                  label:
                  'Checking',
                ),
              ),

              Expanded(
                child:
                _ProgressMilestone(
                  reached:
                  _reached(
                    100,
                  ),
                  icon:
                  Icons.verified_outlined,
                  label:
                  'Done',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProgressMilestone
    extends StatelessWidget {
  final bool reached;
  final IconData icon;
  final String label;

  const _ProgressMilestone({
    required this.reached,
    required this.icon,
    required this.label,
  });

  @override
  Widget build(
      BuildContext context,
      ) {
    return Column(
      children: [
        Container(
          width:
          31,
          height:
          31,
          decoration:
          BoxDecoration(
            color:
            reached
                ? AppColors.primary.withOpacity(
              0.16,
            )
                : AppColors.background,
            shape:
            BoxShape.circle,
            border:
            Border.all(
              color:
              reached
                  ? AppColors.primary
                  : AppColors.border,
            ),
          ),
          child:
          Icon(
            icon,
            size:
            15,
            color:
            reached
                ? AppColors.primary
                : AppColors.textSecondary,
          ),
        ),

        const SizedBox(
          height:
          5,
        ),

        Text(
          label,
          textAlign:
          TextAlign.center,
          style:
          TextStyle(
            color:
            reached
                ? Colors.white
                : AppColors.textSecondary,
            fontSize:
            7,
            fontWeight:
            reached
                ? FontWeight.w600
                : FontWeight.normal,
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// COMMUNITY INTELLIGENCE CARD
// ============================================================================

class _CommunityIntelligenceCard
    extends StatelessWidget {
  final double impactScore;
  final String impactLevel;
  final int affectedCount;
  final int stillExistsCount;
  final int looksFixedCount;
  final int contributionCount;
  final String communityPulse;
  final double resolutionConfidence;

  const _CommunityIntelligenceCard({
    required this.impactScore,
    required this.impactLevel,
    required this.affectedCount,
    required this.stillExistsCount,
    required this.looksFixedCount,
    required this.contributionCount,
    required this.communityPulse,
    required this.resolutionConfidence,
  });

  @override
  Widget build(
      BuildContext context,
      ) {
    final int confidencePercent =
    (resolutionConfidence *
        100)
        .round();

    return Container(
      width:
      double.infinity,
      padding:
      const EdgeInsets.all(
        16,
      ),
      decoration:
      BoxDecoration(
        color:
        AppColors.surface,
        borderRadius:
        BorderRadius.circular(
          18,
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
              Container(
                width:
                39,
                height:
                39,
                decoration:
                BoxDecoration(
                  color:
                  AppColors.primary.withOpacity(
                    0.09,
                  ),
                  borderRadius:
                  BorderRadius.circular(
                    11,
                  ),
                ),
                child:
                const Icon(
                  Icons.insights_outlined,
                  color:
                  AppColors.primary,
                ),
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
                    const Text(
                      'Community Impact Intelligence',
                      style:
                      TextStyle(
                        color:
                        Colors.white,
                        fontSize:
                        13,
                        fontWeight:
                        FontWeight.w700,
                      ),
                    ),

                    Text(
                      impactLevel,
                      style:
                      const TextStyle(
                        color:
                        AppColors.primary,
                        fontSize:
                        8,
                      ),
                    ),
                  ],
                ),
              ),

              Text(
                impactScore.toStringAsFixed(
                  0,
                ),
                style:
                const TextStyle(
                  color:
                  AppColors.primary,
                  fontSize:
                  22,
                  fontWeight:
                  FontWeight.w800,
                ),
              ),
            ],
          ),

          const SizedBox(
            height:
            14,
          ),

          Row(
            children: [
              _ImpactMetric(
                icon:
                Icons.groups_outlined,
                value:
                affectedCount,
                label:
                'Affected',
              ),

              _ImpactMetric(
                icon:
                Icons.warning_amber_outlined,
                value:
                stillExistsCount,
                label:
                'Still Exists',
              ),

              _ImpactMetric(
                icon:
                Icons.task_alt_outlined,
                value:
                looksFixedCount,
                label:
                'Looks Fixed',
              ),

              _ImpactMetric(
                icon:
                Icons.collections_outlined,
                value:
                contributionCount,
                label:
                'Evidence',
              ),
            ],
          ),

          const SizedBox(
            height:
            14,
          ),

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
              AppColors.background.withOpacity(
                0.55,
              ),
              borderRadius:
              BorderRadius.circular(
                11,
              ),
            ),
            child:
            Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Text(
                  communityPulse,
                  style:
                  const TextStyle(
                    color:
                    Colors.white,
                    fontSize:
                    9,
                    fontWeight:
                    FontWeight.w600,
                  ),
                ),

                const SizedBox(
                  height:
                  7,
                ),

                Row(
                  children: [
                    Expanded(
                      child:
                      ClipRRect(
                        borderRadius:
                        BorderRadius.circular(
                          20,
                        ),
                        child:
                        LinearProgressIndicator(
                          value:
                          resolutionConfidence,
                          minHeight:
                          6,
                          backgroundColor:
                          AppColors.border,
                        ),
                      ),
                    ),

                    const SizedBox(
                      width:
                      8,
                    ),

                    Text(
                      '$confidencePercent% fixed signal',
                      style:
                      const TextStyle(
                        color:
                        AppColors.textSecondary,
                        fontSize:
                        8,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ImpactMetric
    extends StatelessWidget {
  final IconData icon;
  final int value;
  final String label;

  const _ImpactMetric({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(
      BuildContext context,
      ) {
    return Expanded(
      child:
      Column(
        children: [
          Icon(
            icon,
            color:
            AppColors.primary,
            size:
            18,
          ),

          const SizedBox(
            height:
            4,
          ),

          Text(
            '$value',
            style:
            const TextStyle(
              color:
              Colors.white,
              fontSize:
              14,
              fontWeight:
              FontWeight.w800,
            ),
          ),

          Text(
            label,
            textAlign:
            TextAlign.center,
            style:
            const TextStyle(
              color:
              AppColors.textSecondary,
              fontSize:
              7,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// ACTION SECTION CARD
// ============================================================================

class _ActionSectionCard
    extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Widget child;
  final Widget? trailing;

  const _ActionSectionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.child,
    this.trailing,
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
          Row(
            children: [
              Container(
                width:
                36,
                height:
                36,
                decoration:
                BoxDecoration(
                  color:
                  AppColors.primary.withOpacity(
                    0.08,
                  ),
                  borderRadius:
                  BorderRadius.circular(
                    10,
                  ),
                ),
                child:
                Icon(
                  icon,
                  color:
                  AppColors.primary,
                  size:
                  19,
                ),
              ),

              const SizedBox(
                width:
                9,
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
                        color:
                        Colors.white,
                        fontSize:
                        12,
                        fontWeight:
                        FontWeight.w700,
                      ),
                    ),

                    const SizedBox(
                      height:
                      2,
                    ),

                    Text(
                      subtitle,
                      style:
                      const TextStyle(
                        color:
                        AppColors.textSecondary,
                        fontSize:
                        8,
                        height:
                        1.35,
                      ),
                    ),
                  ],
                ),
              ),

              if (trailing !=
                  null)
                trailing!,
            ],
          ),

          const SizedBox(
            height:
            13,
          ),

          child,
        ],
      ),
    );
  }
}

// ============================================================================
// FEEDBACK BUTTON
// ============================================================================

class _FeedbackButton
    extends StatelessWidget {
  final bool selected;
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  const _FeedbackButton({
    required this.selected,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(
      BuildContext context,
      ) {
    return OutlinedButton.icon(
      onPressed:
      onPressed,
      style:
      OutlinedButton.styleFrom(
        backgroundColor:
        selected
            ? AppColors.primary.withOpacity(
          0.10,
        )
            : null,
        side:
        BorderSide(
          color:
          selected
              ? AppColors.primary
              : AppColors.border,
        ),
        padding:
        const EdgeInsets.symmetric(
          vertical:
          12,
          horizontal:
          8,
        ),
      ),
      icon:
      Icon(
        selected
            ? Icons.check_circle
            : icon,
        size:
        18,
      ),
      label:
      Text(
        label,
      ),
    );
  }
}

// ============================================================================
// LIVE SYNC BADGE
// ============================================================================

class _LiveSyncBadge
    extends StatelessWidget {
  final bool refreshing;
  final String label;
  final VoidCallback onTap;

  const _LiveSyncBadge({
    required this.refreshing,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(
      BuildContext context,
      ) {
    return InkWell(
      onTap:
      refreshing
          ? null
          : onTap,
      borderRadius:
      BorderRadius.circular(
        20,
      ),
      child:
      Container(
        padding:
        const EdgeInsets.symmetric(
          horizontal:
          9,
          vertical:
          7,
        ),
        decoration:
        BoxDecoration(
          color:
          AppColors.surface,
          borderRadius:
          BorderRadius.circular(
            20,
          ),
          border:
          Border.all(
            color:
            AppColors.border,
          ),
        ),
        child:
        Row(
          mainAxisSize:
          MainAxisSize.min,
          children: [
            refreshing
                ? const SizedBox(
              width:
              13,
              height:
              13,
              child:
              CircularProgressIndicator(
                strokeWidth:
                2,
              ),
            )
                : const Icon(
              Icons.sync_rounded,
              size:
              14,
              color:
              AppColors.primary,
            ),

            const SizedBox(
              width:
              5,
            ),

            Text(
              label,
              style:
              const TextStyle(
                color:
                AppColors.textSecondary,
                fontSize:
                7,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// STATUS / INFO PILLS
// ============================================================================

class _StatusPill
    extends StatelessWidget {
  final String status;

  const _StatusPill({
    required this.status,
  });

  @override
  Widget build(
      BuildContext context,
      ) {
    return Container(
      padding:
      const EdgeInsets.symmetric(
        horizontal:
        9,
        vertical:
        6,
      ),
      decoration:
      BoxDecoration(
        color:
        AppColors.primary.withOpacity(
          0.10,
        ),
        borderRadius:
        BorderRadius.circular(
          20,
        ),
      ),
      child:
      Text(
        status.toUpperCase(),
        style:
        const TextStyle(
          color:
          AppColors.primary,
          fontSize:
          8,
          fontWeight:
          FontWeight.w700,
        ),
      ),
    );
  }
}

class _InfoPill
    extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoPill({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(
      BuildContext context,
      ) {
    return Container(
      padding:
      const EdgeInsets.symmetric(
        horizontal:
        8,
        vertical:
        5,
      ),
      decoration:
      BoxDecoration(
        color:
        AppColors.background.withOpacity(
          0.55,
        ),
        borderRadius:
        BorderRadius.circular(
          20,
        ),
      ),
      child:
      Row(
        mainAxisSize:
        MainAxisSize.min,
        children: [
          Icon(
            icon,
            size:
            12,
            color:
            AppColors.primary,
          ),

          const SizedBox(
            width:
            4,
          ),

          Text(
            text,
            style:
            const TextStyle(
              color:
              AppColors.textSecondary,
              fontSize:
              8,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// EVIDENCE CARD
// ============================================================================

class _EvidenceCard
    extends StatelessWidget {
  final CommunityContribution item;
  final int index;
  final VoidCallback? onRemove;

  const _EvidenceCard({
    required this.item,
    required this.index,
    required this.onRemove,
  });

  @override
  Widget build(
      BuildContext context,
      ) {
    return Container(
      decoration:
      BoxDecoration(
        color:
        AppColors.background.withOpacity(
          0.55,
        ),
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
          SizedBox(
            height:
            150,
            child:
            Stack(
              children: [
                Positioned.fill(
                  child:
                  ClipRRect(
                    borderRadius:
                    const BorderRadius.vertical(
                      top:
                      Radius.circular(
                        12,
                      ),
                    ),
                    child:
                    item.isImage &&
                        item.signedUrl !=
                            null
                        ? Image.network(
                      item.signedUrl!,
                      fit:
                      BoxFit.cover,
                      errorBuilder:
                          (
                          context,
                          error,
                          stack,
                          ) =>
                      const Center(
                        child:
                        Icon(
                          Icons.broken_image_outlined,
                          color:
                          AppColors.textSecondary,
                        ),
                      ),
                    )
                        : Container(
                      color:
                      AppColors.background,
                      child:
                      Center(
                        child:
                        Column(
                          mainAxisSize:
                          MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.play_circle_outline_rounded,
                              size:
                              44,
                              color:
                              AppColors.primary,
                            ),
                            const SizedBox(
                              height:
                              5,
                            ),
                            Text(
                              item.isVideo
                                  ? 'Community Video'
                                  : 'Evidence',
                              style:
                              const TextStyle(
                                color:
                                AppColors.textSecondary,
                                fontSize:
                                8,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                Positioned(
                  left:
                  8,
                  bottom:
                  8,
                  child:
                  Container(
                    padding:
                    const EdgeInsets.symmetric(
                      horizontal:
                      8,
                      vertical:
                      4,
                    ),
                    decoration:
                    BoxDecoration(
                      color:
                      Colors.black.withOpacity(
                        0.70,
                      ),
                      borderRadius:
                      BorderRadius.circular(
                        20,
                      ),
                    ),
                    child:
                    Text(
                      '${item.isImage ? 'PHOTO' : 'VIDEO'} '
                          '${index + 1}',
                      style:
                      const TextStyle(
                        color:
                        Colors.white,
                        fontSize:
                        8,
                        fontWeight:
                        FontWeight.w700,
                      ),
                    ),
                  ),
                ),

                if (item.isMine)
                  Positioned(
                    left:
                    8,
                    top:
                    8,
                    child:
                    Container(
                      padding:
                      const EdgeInsets.symmetric(
                        horizontal:
                        8,
                        vertical:
                        4,
                      ),
                      decoration:
                      BoxDecoration(
                        color:
                        AppColors.primary.withOpacity(
                          0.88,
                        ),
                        borderRadius:
                        BorderRadius.circular(
                          20,
                        ),
                      ),
                      child:
                      const Text(
                        'YOUR CONTRIBUTION',
                        style:
                        TextStyle(
                          color:
                          Colors.white,
                          fontSize:
                          7,
                          fontWeight:
                          FontWeight.w700,
                        ),
                      ),
                    ),
                  ),

                if (onRemove !=
                    null)
                  Positioned(
                    right:
                    5,
                    top:
                    5,
                    child:
                    Container(
                      decoration:
                      BoxDecoration(
                        color:
                        Colors.black.withOpacity(
                          0.66,
                        ),
                        shape:
                        BoxShape.circle,
                      ),
                      child:
                      IconButton(
                        onPressed:
                        onRemove,
                        icon:
                        const Icon(
                          Icons.delete_outline,
                          color:
                          Colors.white,
                          size:
                          18,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          if ((item.note ??
              '')
              .trim()
              .isNotEmpty)
            Padding(
              padding:
              const EdgeInsets.all(
                11,
              ),
              child:
              Row(
                crossAxisAlignment:
                CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.notes_rounded,
                    color:
                    AppColors.primary,
                    size:
                    15,
                  ),

                  const SizedBox(
                    width:
                    7,
                  ),

                  Expanded(
                    child:
                    Text(
                      item.note!,
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
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ============================================================================
// EMPTY EVIDENCE
// ============================================================================

class _EmptyEvidenceState
    extends StatelessWidget {
  const _EmptyEvidenceState();

  @override
  Widget build(
      BuildContext context,
      ) {
    return Container(
      width:
      double.infinity,
      padding:
      const EdgeInsets.symmetric(
        horizontal:
        14,
        vertical:
        20,
      ),
      decoration:
      BoxDecoration(
        color:
        AppColors.background.withOpacity(
          0.45,
        ),
        borderRadius:
        BorderRadius.circular(
          12,
        ),
      ),
      child:
      const Column(
        children: [
          Icon(
            Icons.add_photo_alternate_outlined,
            color:
            AppColors.textSecondary,
            size:
            31,
          ),

          SizedBox(
            height:
            8,
          ),

          Text(
            'No community evidence yet',
            style:
            TextStyle(
              color:
              Colors.white,
              fontSize:
              10,
              fontWeight:
              FontWeight.w700,
            ),
          ),

          SizedBox(
            height:
            4,
          ),

          Text(
            'Be the first to contribute a current photo or short video.',
            textAlign:
            TextAlign.center,
            style:
            TextStyle(
              color:
              AppColors.textSecondary,
              fontSize:
              8,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// TRUST CARD
// ============================================================================

class _CommunityTrustCard
    extends StatelessWidget {
  const _CommunityTrustCard();

  @override
  Widget build(
      BuildContext context,
      ) {
    return Container(
      width:
      double.infinity,
      padding:
      const EdgeInsets.all(
        13,
      ),
      decoration:
      BoxDecoration(
        color:
        AppColors.primary.withOpacity(
          0.055,
        ),
        borderRadius:
        BorderRadius.circular(
          13,
        ),
        border:
        Border.all(
          color:
          AppColors.primary.withOpacity(
            0.24,
          ),
        ),
      ),
      child:
      const Row(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.shield_outlined,
            color:
            AppColors.primary,
            size:
            18,
          ),

          SizedBox(
            width:
            9,
          ),

          Expanded(
            child:
            Text(
              'Community signals are supporting information only. '
                  'Official priority, assignment, progress and resolution remain '
                  'controlled by the authorised infrastructure workflow. '
                  'Contributor identity is not displayed publicly.',
              style:
              TextStyle(
                color:
                AppColors.textSecondary,
                fontSize:
                8,
                height:
                1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// FRIENDLY LOADING
// ============================================================================

class _FriendlyLoadingState
    extends StatelessWidget {
  const _FriendlyLoadingState();

  @override
  Widget build(
      BuildContext context,
      ) {
    return Center(
      child:
      Column(
        mainAxisSize:
        MainAxisSize.min,
        children: [
          Container(
            width:
            58,
            height:
            58,
            decoration:
            BoxDecoration(
              color:
              AppColors.primary.withOpacity(
                0.08,
              ),
              shape:
              BoxShape.circle,
            ),
            child:
            const Padding(
              padding:
              EdgeInsets.all(
                16,
              ),
              child:
              CircularProgressIndicator(
                strokeWidth:
                3,
              ),
            ),
          ),

          const SizedBox(
            height:
            13,
          ),

          const Text(
            'Loading community intelligence...',
            style:
            TextStyle(
              color:
              Colors.white,
              fontWeight:
              FontWeight.w600,
            ),
          ),

          const SizedBox(
            height:
            5,
          ),

          const Text(
            'Checking current report progress and community activity',
            style:
            TextStyle(
              color:
              AppColors.textSecondary,
              fontSize:
              9,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// FRIENDLY ERROR
// ============================================================================

class _FriendlyErrorState
    extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;

  const _FriendlyErrorState({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(
      BuildContext context,
      ) {
    return Center(
      child:
      Padding(
        padding:
        const EdgeInsets.all(
          28,
        ),
        child:
        Column(
          mainAxisSize:
          MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_outlined,
              size:
              42,
              color:
              AppColors.textSecondary,
            ),

            const SizedBox(
              height:
              12,
            ),

            const Text(
              'Community data is temporarily unavailable',
              textAlign:
              TextAlign.center,
              style:
              TextStyle(
                color:
                Colors.white,
                fontWeight:
                FontWeight.w700,
              ),
            ),

            const SizedBox(
              height:
              6,
            ),

            Text(
              message,
              textAlign:
              TextAlign.center,
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

            const SizedBox(
              height:
              14,
            ),

            OutlinedButton.icon(
              onPressed:
              onRetry,
              icon:
              const Icon(
                Icons.refresh_rounded,
              ),
              label:
              const Text(
                'Try Again',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
