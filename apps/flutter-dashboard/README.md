# Edge Analytics Flutter Dashboard

A Flutter application that visualizes IoT telemetry data from Redis hot cache and ClickHouse.

## Features

### Data Sources

**Redis (Hot Cache - 15 min TTL)**
- `metrics:avg:temperature:5m` - 5-minute average temperature
- `metrics:avg:pressure:5m` - 5-minute average pressure  
- `metrics:throughput:msg_per_sec` - Message throughput

**ClickHouse (Historical Data)**
- Temperature time-series (60 minutes)
- Hourly event aggregations (24 hours)
- Device statistics table

## Screenshots

```
┌─────────────────────────────────────────────────────────────┐
│  Edge Analytics Dashboard                    Updated: 14:32 │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ⚡ Redis Hot Cache Metrics                                 │
│  ┌──────────────┐ ┌──────────────┐ ┌──────────────┐        │
│  │ Avg Temp     │ │ Avg Pressure │ │ Throughput   │        │
│  │   25.4°C     │ │  1013.2 hPa  │ │   145 msg/s  │        │
│  │ [Redis]      │ │ [Redis]      │ │ [Redis]      │        │
│  └──────────────┘ └──────────────┘ └──────────────┘        │
│                                                             │
│  🌡️ Temperature Trend (ClickHouse)                         │
│  ┌─────────────────────────────────────────────────────┐   │
│  │     ╱╲    ╱╲                                        │   │
│  │    ╱  ╲  ╱  ╲     ╱╲                               │   │
│  │   ╱    ╲╱    ╲   ╱  ╲                              │   │
│  │  ╱            ╲_╱    ╲___                          │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                             │
│  📊 Events per Hour (ClickHouse)                           │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  █  █        █                                      │   │
│  │  █  █  █  █  █  █                                   │   │
│  │  █  █  █  █  █  █  █  █                             │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

## Getting Started

### Prerequisites

- Flutter SDK 3.0+
- Dashboard API running (port 8081)

### Installation

```bash
cd apps/flutter-dashboard

# Get dependencies
flutter pub get

# Run on web
flutter run -d chrome

# Run on desktop
flutter run -d macos  # or windows, linux

# Build web release
flutter build web
```

### Configuration

Edit `lib/services/metrics_service.dart` to set the API URL:

```dart
class MetricsService {
  // For local development with port-forward
  final String baseUrl = 'http://localhost:8081';
  
  // For production
  // final String baseUrl = 'http://dashboard-api.edge.svc.cluster.local:8080';
}
```

### Port Forward Dashboard API

```bash
kubectl port-forward -n edge svc/dashboard-api 8081:8080
```

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Flutter Dashboard                         │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐     │
│  │ MetricCard  │    │ TempChart   │    │ EventsChart │     │
│  │  (Redis)    │    │ (ClickHouse)│    │ (ClickHouse)│     │
│  └──────┬──────┘    └──────┬──────┘    └──────┬──────┘     │
│         │                  │                  │             │
│         └──────────────────┼──────────────────┘             │
│                            │                                │
│                  ┌─────────▼─────────┐                      │
│                  │ MetricsProvider   │                      │
│                  │ (State Management)│                      │
│                  └─────────┬─────────┘                      │
│                            │                                │
│                  ┌─────────▼─────────┐                      │
│                  │  MetricsService   │                      │
│                  │   (HTTP Client)   │                      │
│                  └─────────┬─────────┘                      │
│                            │                                │
└────────────────────────────┼────────────────────────────────┘
                             │
                   ┌─────────▼─────────┐
                   │   Dashboard API   │
                   │     (FastAPI)     │
                   └────────┬──────────┘
                            │
              ┌─────────────┼─────────────┐
              │             │             │
        ┌─────▼─────┐ ┌─────▼─────┐      │
        │   Redis   │ │ ClickHouse│      │
        │ Hot Cache │ │ Time-Series│     │
        └───────────┘ └───────────┘      │
```

## API Endpoints

| Endpoint | Source | Description |
|----------|--------|-------------|
| `/api/dashboard/redis-metrics` | Redis | Hot cache metrics |
| `/api/dashboard/clickhouse/temperature-timeseries` | ClickHouse | Temperature time-series |
| `/api/dashboard/clickhouse/hourly-stats` | ClickHouse | Hourly aggregations |
| `/api/dashboard/clickhouse/device-stats` | ClickHouse | Device statistics |

## Auto-Refresh

- Redis metrics: Every 10 seconds
- ClickHouse data: On pull-to-refresh or manual

## Building for Production

```bash
# Web
flutter build web --release
# Output: build/web/

# Desktop
flutter build macos --release
flutter build windows --release
flutter build linux --release

# Deploy web build
cp -r build/web/* /path/to/nginx/html/
```
