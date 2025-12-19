/// Redis-cached metrics (hot cache with 15 min TTL)
class RedisMetrics {
  final double avgTemperature;
  final double avgPressure;
  final double throughput;
  final int activeDevices;
  final int warningCount;
  final int anomalyCount;
  final DateTime timestamp;

  RedisMetrics({
    required this.avgTemperature,
    required this.avgPressure,
    required this.throughput,
    required this.activeDevices,
    required this.warningCount,
    required this.anomalyCount,
    required this.timestamp,
  });

  factory RedisMetrics.fromJson(Map<String, dynamic> json) {
    return RedisMetrics(
      avgTemperature: (json['avg_temperature'] ?? 0).toDouble(),
      avgPressure: (json['avg_pressure'] ?? 0).toDouble(),
      throughput: (json['throughput'] ?? 0).toDouble(),
      activeDevices: json['active_devices'] ?? 0,
      warningCount: json['warning_count'] ?? 0,
      anomalyCount: json['anomaly_count'] ?? 0,
      timestamp: DateTime.tryParse(json['timestamp'] ?? '') ?? DateTime.now(),
    );
  }

  factory RedisMetrics.empty() {
    return RedisMetrics(
      avgTemperature: 0,
      avgPressure: 0,
      throughput: 0,
      activeDevices: 0,
      warningCount: 0,
      anomalyCount: 0,
      timestamp: DateTime.now(),
    );
  }
}

/// ClickHouse time-series data point
class TimeSeriesPoint {
  final DateTime timestamp;
  final double value;
  final String? deviceId;

  TimeSeriesPoint({
    required this.timestamp,
    required this.value,
    this.deviceId,
  });

  factory TimeSeriesPoint.fromJson(Map<String, dynamic> json, String valueKey) {
    return TimeSeriesPoint(
      timestamp: DateTime.tryParse(json['timestamp'] ?? json['time'] ?? '') ?? DateTime.now(),
      value: (json[valueKey] ?? 0).toDouble(),
      deviceId: json['device_id'],
    );
  }
}

/// ClickHouse aggregated device stats
class DeviceStats {
  final String deviceId;
  final String deviceType;
  final String location;
  final int totalEvents;
  final double avgTemperature;
  final double avgPressure;
  final double avgHumidity;
  final double batteryLevel;
  final int warnings;
  final DateTime lastSeen;

  DeviceStats({
    required this.deviceId,
    required this.deviceType,
    required this.location,
    required this.totalEvents,
    required this.avgTemperature,
    required this.avgPressure,
    required this.avgHumidity,
    required this.batteryLevel,
    required this.warnings,
    required this.lastSeen,
  });

  factory DeviceStats.fromJson(Map<String, dynamic> json) {
    return DeviceStats(
      deviceId: json['device_id'] ?? '',
      deviceType: json['device_type'] ?? '',
      location: json['location'] ?? '',
      totalEvents: json['total_events'] ?? 0,
      avgTemperature: (json['avg_temperature'] ?? 0).toDouble(),
      avgPressure: (json['avg_pressure'] ?? 0).toDouble(),
      avgHumidity: (json['avg_humidity'] ?? 0).toDouble(),
      batteryLevel: (json['battery_level'] ?? 0).toDouble(),
      warnings: json['warnings'] ?? 0,
      lastSeen: DateTime.tryParse(json['last_seen'] ?? '') ?? DateTime.now(),
    );
  }
}

/// ClickHouse hourly aggregation
class HourlyStats {
  final DateTime hour;
  final int events;
  final double avgTemperature;
  final double maxTemperature;
  final double minTemperature;
  final double avgPressure;
  final int warnings;

  HourlyStats({
    required this.hour,
    required this.events,
    required this.avgTemperature,
    required this.maxTemperature,
    required this.minTemperature,
    required this.avgPressure,
    required this.warnings,
  });

  factory HourlyStats.fromJson(Map<String, dynamic> json) {
    return HourlyStats(
      hour: DateTime.tryParse(json['hour'] ?? json['timestamp'] ?? '') ?? DateTime.now(),
      events: json['events'] ?? 0,
      avgTemperature: (json['avg_temperature'] ?? json['avg_temp'] ?? 0).toDouble(),
      maxTemperature: (json['max_temperature'] ?? json['max_temp'] ?? 0).toDouble(),
      minTemperature: (json['min_temperature'] ?? json['min_temp'] ?? 0).toDouble(),
      avgPressure: (json['avg_pressure'] ?? 0).toDouble(),
      warnings: json['warnings'] ?? 0,
    );
  }
}
