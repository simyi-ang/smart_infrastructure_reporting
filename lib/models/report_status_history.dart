class ReportStatusHistory {
  final String id;
  final String reportId;
  final String status;
  final String? note;
  final DateTime createdAt;

  const ReportStatusHistory({
    required this.id,
    required this.reportId,
    required this.status,
    required this.note,
    required this.createdAt,
  });

  factory ReportStatusHistory.fromMap(
      Map<String, dynamic> map,
      ) {
    return ReportStatusHistory(
      id:
      map['id']?.toString() ??
          '',
      reportId:
      map['report_id']?.toString() ??
          '',
      status:
      map['status']?.toString() ??
          'pending',
      note:
      map['note']?.toString(),
      createdAt:
      DateTime.tryParse(
        map['created_at']?.toString() ??
            '',
      ) ??
          DateTime.now(),
    );
  }
}