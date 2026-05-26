import 'dart:async';
import 'connectivity_helper.dart';

class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._();
  factory ConnectivityService() => _instance;
  ConnectivityService._();

  final _controller = StreamController<bool>.broadcast();
  Timer? _timer;
  bool _lastStatus = true;

  Stream<bool> get onConnectivityChanged => _controller.stream;
  bool get isConnected => _lastStatus;

  void init() {
    _checkStatus();
    // Poll every 10 seconds to detect connection changes
    _timer = Timer.periodic(const Duration(seconds: 10), (_) => _checkStatus());
  }

  void dispose() {
    _timer?.cancel();
    _controller.close();
  }

  Future<void> _checkStatus() async {
    final status = await checkNetwork();
    if (status != _lastStatus) {
      _lastStatus = status;
      _controller.add(status);
    }
  }

  Future<bool> checkNetwork() async {
    return checkWebNetwork();
  }
}

final connectivityService = ConnectivityService();
