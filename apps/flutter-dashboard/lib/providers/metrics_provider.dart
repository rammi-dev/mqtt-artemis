import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/metrics.dart';
import '../services/metrics_service.dart';

class MetricsProvider with ChangeNotifier {
  final MetricsService _service;
  
  // Redis metrics (hot cache)
  RedisMetrics _redisMetrics = RedisMetrics.empty();
  RedisMetrics get redisMetrics => _redisMetrics;
  
  // ClickHouse data
  List<TimeSeriesPoint> _temperatureData = [];
  List<TimeSeriesPoint> get temperatureData => _temperatureData;
  
  List<HourlyStats> _hourlyStats = [];
  List<HourlyStats> get hourlyStats => _hourlyStats;
  
  List<DeviceStats> _deviceStats = [];
  List<DeviceStats> get deviceStats => _deviceStats;
  
  // State
  bool _isLoading = false;
  bool get isLoading => _isLoading;
  
  String? _error;
  String? get error => _error;
  
  DateTime? _lastUpdated;
  DateTime? get lastUpdated => _lastUpdated;
  
  // Auto-refresh timer
  Timer? _refreshTimer;
  
  MetricsProvider(this._service) {
    // Initial load
    refresh();
    
    // Auto-refresh every 10 seconds for Redis metrics
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      refreshRedisMetrics();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  /// Refresh all data
  Future<void> refresh() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await Future.wait([
        refreshRedisMetrics(),
        refreshTemperatureData(),
        refreshHourlyStats(),
        refreshDeviceStats(),
      ]);
      
      _lastUpdated = DateTime.now();
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Refresh Redis cached metrics only (fast)
  Future<void> refreshRedisMetrics() async {
    try {
      _redisMetrics = await _service.getRedisMetrics();
      notifyListeners();
    } catch (e) {
      debugPrint('Error refreshing Redis metrics: $e');
    }
  }

  /// Refresh temperature time-series from ClickHouse
  Future<void> refreshTemperatureData() async {
    try {
      _temperatureData = await _service.getTemperatureTimeSeries();
      notifyListeners();
    } catch (e) {
      debugPrint('Error refreshing temperature data: $e');
    }
  }

  /// Refresh hourly stats from ClickHouse
  Future<void> refreshHourlyStats() async {
    try {
      _hourlyStats = await _service.getHourlyStats();
      notifyListeners();
    } catch (e) {
      debugPrint('Error refreshing hourly stats: $e');
    }
  }

  /// Refresh device stats from ClickHouse
  Future<void> refreshDeviceStats() async {
    try {
      _deviceStats = await _service.getDeviceStats();
      notifyListeners();
    } catch (e) {
      debugPrint('Error refreshing device stats: $e');
    }
  }
}
