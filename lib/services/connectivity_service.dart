import 'dart:async';
import 'dart:io';

class ConnectivityService {
  const ConnectivityService();

  Future<bool> hasInternetConnection() async {
    try {
      final List<InternetAddress> result =
      await InternetAddress.lookup(
        'example.com',
      ).timeout(
        const Duration(seconds: 5),
      );

      return result.isNotEmpty &&
          result.first.rawAddress.isNotEmpty;
    } on SocketException {
      return false;
    } on TimeoutException {
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<void> requireInternetConnection() async {
    final bool connected =
    await hasInternetConnection();

    if (!connected) {
      throw Exception(
        'No internet connection. Your report information has been kept on this screen. '
            'Reconnect to the internet and tap Retry Submission.',
      );
    }
  }
}
