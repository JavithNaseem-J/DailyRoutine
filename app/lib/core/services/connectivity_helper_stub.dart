import 'dart:io';

Future<bool> checkWebNetwork() async {
  try {
    final result = await InternetAddress.lookup('supabase.co');
    return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
  } on SocketException catch (_) {
    return false;
  } catch (_) {
    return false;
  }
}
