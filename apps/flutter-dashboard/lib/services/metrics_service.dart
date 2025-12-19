import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/metrics.dart';

/// Service to fetch metrics from Dashboard API
/// The API reads from Redis (hot cache) and ClickHouse (historical data)
class MetricsService {
  // Configure based on your environment
  // For local development with port-forward: http://localhost:8081
  // For in-cluster: http://dashboard-api.edge.svc.cluster.local:8080
  final String baseUrl;
  
  MetricsService({this.baseUrl = 'http://localhost:8081'});

  /// Get Redis cached metrics (3 metrics: avg temp, avg pressure, throughput)
  Future<RedisMetrics> getRedisMetrics() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/dashboard/redis-metrics'),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        return RedisMetrics.fromJson(json);
      }
      throw Exception('Failed to load Redis metrics: ${response.statusCode}');
    } catch (e) {
      // Return mock data for demo/development
      return _getMockRedisMetrics();
    }
  }

  /// Get ClickHouse time-series data (temperature over time)
  Future<List<TimeSeriesPoint>> getTemperatureTimeSeries({
    Duration duration = const Duration(hours: 1),
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/dashboard/clickhouse/temperature-timeseries'
            '?duration_minutes=${duration.inMinutes}'),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List<dynamic> json = jsonDecode(response.body);
        return json.map((e) => TimeSeriesPoint.fromJson(e, 'avg_temp')).toList();
      }
      throw Exception('Failed to load temperature data');
    } catch (e) {
      return _getMockTemperatureData();
    }
  }

  /// Get ClickHouse hourly aggregation (events per hour)
  Future<List<HourlyStats>> getHourlyStats({int hours = 24}) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/dashboard/clickhouse/hourly-stats?hours=$hours'),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List<dynamic> json = jsonDecode(response.body);
        return json.map((e) => HourlyStats.fromJson(e)).toList();
      }
      throw Exception('Failed to load hourly stats');
    } catch (e) {
      return _getMockHourlyStats();
    }
  }

  /// Get device statistics from ClickHouse
  Future<List<DeviceStats>> getDeviceStats({int limit = 20}) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/dashboard/clickhouse/device-stats?limit=$limit'),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List<dynamic> json = jsonDecode(response.body);
        return json.map((e) => DeviceStats.fromJson(e)).toList();
      }
      throw Exception('Failed to load device stats');
    } catch (e) {
      return _getMockDeviceStats();
    }
  }

  // ============================================
  // Mock data for development/demo
  // ============================================

  RedisMetrics _getMockRedisMetrics() {
    return RedisMetrics(
      avgTemperature: 25.4 + (DateTime.now().second % 10) * 0.1,
      avgPressure: 1013.2 + (DateTime.now().second % 5) * 0.5,
      throughput: 145.0 + (DateTime.now().second % 20),
      activeDevices: 47,
      warningCount: 3,
      anomalyCount: 1,
      timestamp: DateTime.now(),
    );
  }

  List<TimeSeriesPoint> _getMockTemperatureData() {
    final now = DateTime.now();
    return List.generate(60, (i) {
      final time = now.subtract(Duration(minutes: 60 - i));
      // Simulate daily temperature cycle
      final baseTemp = 25.0;
      final hourFactor = (time.hour - 6) * 3.14159 / 12;
      final temp = baseTemp + 5 * (hourFactor > 0 ? 1 : -1) * 
          (hourFactor.abs() < 3.14159 ? hourFactor.abs() / 3.14159 : 1) +
          (i % 5) * 0.2;
      return TimeSeriesPoint(
        timestamp: time,
        value: temp,
      );
    });
  }

  List<HourlyStats> _getMockHourlyStats() {
    final now = DateTime.now();
    return List.generate(24, (i) {
      final hour = now.subtract(Duration(hours: 24 - i));
      final isWorkHour = hour.hour >= 8 && hour.hour <= 18;
      return HourlyStats(
        hour: hour,
        events: isWorkHour ? 5000 + (i * 100) : 2000 + (i * 50),
        avgTemperature: 24.0 + (i % 6) * 0.5,
        maxTemperature: 28.0 + (i % 4) * 0.3,
        minTemperature: 20.0 + (i % 5) * 0.2,
        avgPressure: 1013.0 + (i % 3) * 0.5,
        warnings: i % 4,
      );
    });
  }

  List<DeviceStats> _getMockDeviceStats() {
    final locations = ['floor-1-north', 'floor-1-south', 'warehouse-a', 'server-room'];
    final types = ['temperature-sensor', 'pressure-sensor', 'multi-sensor'];
    
    return List.generate(20, (i) {
      return DeviceStats(
        deviceId: 'device-${(i + 1).toString().padLeft(4, '0')}',
        deviceType: types[i % 3],
        location: locations[i % 4],
        totalEvents: 1000 + (i * 50),
        avgTemperature: 24.0 + (i % 5) * 0.5,
        avgPressure: 1012.0 + (i % 4) * 0.8,
        avgHumidity: 55.0 + (i % 6) * 2,
        batteryLevel: 100.0 - (i * 2),
        warnings: i % 5,
        lastSeen: DateTime.now().subtract(Duration(minutes: i * 2)),
      );
    });
  }
}
