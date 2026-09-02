import 'dart:convert';
import 'dart:io';

import '../models/malaysia_open_data.dart';

class MalaysiaOpenDataService {
  static const String datasetId =
      'ridership_headline';

  static const String datasetTitle =
      'Daily Public Transport Ridership';

  static const String sourceName =
      'data.gov.my • Prasarana Malaysia • Ministry of Transport';

  static const String licence =
      'CC BY 4.0';

  static final Uri _latestUri =
  Uri.https(
    'api.data.gov.my',
    '/data-catalogue',
    {
      'id':
      datasetId,
      'sort':
      '-date',
      'limit':
      '30',
    },
  );

  // ============================================================
  // GET LATEST GOVERNMENT OPEN DATA
  // ============================================================

  Future<MalaysiaOpenDataSummary>
  getPublicTransportSummary() async {
    final HttpClient client =
    HttpClient();

    client.connectionTimeout =
    const Duration(
      seconds: 12,
    );

    try {
      final HttpClientRequest request =
      await client.getUrl(
        _latestUri,
      );

      request.headers.set(
        HttpHeaders.acceptHeader,
        'application/json',
      );

      final HttpClientResponse response =
      await request.close();

      final String body =
      await response
          .transform(
        utf8.decoder,
      )
          .join();

      if (response.statusCode < 200 ||
          response.statusCode >= 300) {
        throw Exception(
          'Government Open Data request failed '
              '(HTTP ${response.statusCode}).',
        );
      }

      final dynamic decoded =
      jsonDecode(
        body,
      );

      if (decoded is! List) {
        throw Exception(
          'Unexpected response from data.gov.my.',
        );
      }

      final List<PublicTransportRidership>
      records = decoded
          .whereType<Map>()
          .map(
            (item) =>
            PublicTransportRidership.fromMap(
              Map<String, dynamic>.from(
                item,
              ),
            ),
      )
          .toList();

      if (records.isEmpty) {
        throw Exception(
          'No public transport data is currently available.',
        );
      }

      records.sort(
            (a, b) =>
            b.date.compareTo(
              a.date,
            ),
      );

      return MalaysiaOpenDataSummary(
        latest:
        records.first,
        recent:
        records,
      );
    } on SocketException {
      throw Exception(
        'No internet connection. Government Open Data could not be loaded.',
      );
    } on HandshakeException {
      throw Exception(
        'Secure connection to data.gov.my could not be established.',
      );
    } on FormatException {
      throw Exception(
        'Government Open Data returned an invalid response.',
      );
    } catch (e) {
      final String message =
      e.toString().replaceFirst(
        'Exception: ',
        '',
      );

      throw Exception(
        message,
      );
    } finally {
      client.close(
        force: true,
      );
    }
  }

  // ============================================================
  // NUMBER FORMATTER
  // ============================================================

  String formatNumber(
      int value,
      ) {
    final String text =
    value.toString();

    final StringBuffer result =
    StringBuffer();

    for (int i = 0;
    i < text.length;
    i++) {
      if (i > 0 &&
          (text.length - i) % 3 ==
              0) {
        result.write(
          ',',
        );
      }

      result.write(
        text[i],
      );
    }

    return result.toString();
  }

  // ============================================================
  // DATE
  // ============================================================

  String formatDate(
      DateTime date,
      ) {
    const List<String> months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    return '${date.day} '
        '${months[date.month - 1]} '
        '${date.year}';
  }
}
