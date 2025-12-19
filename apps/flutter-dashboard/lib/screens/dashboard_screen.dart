import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/metrics_provider.dart';
import '../widgets/metric_card.dart';
import '../widgets/temperature_chart.dart';
import '../widgets/events_chart.dart';
import '../widgets/device_table.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edge Analytics Dashboard'),
        centerTitle: false,
        actions: [
          Consumer<MetricsProvider>(
            builder: (context, provider, _) {
              return Row(
                children: [
                  if (provider.lastUpdated != null)
                    Text(
                      'Updated: ${DateFormat('HH:mm:ss').format(provider.lastUpdated!)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: provider.isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh),
                    onPressed: provider.isLoading
                        ? null
                        : () => provider.refresh(),
                  ),
                ],
              );
            },
          ),
        ],
      ),
      body: Consumer<MetricsProvider>(
        builder: (context, provider, _) {
          if (provider.error != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 48, color: Colors.red[400]),
                  const SizedBox(height: 16),
                  Text('Error: ${provider.error}'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => provider.refresh(),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => provider.refresh(),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Section: Redis Hot Cache Metrics
                  _buildSectionHeader(
                    context,
                    'Redis Hot Cache Metrics',
                    'Real-time metrics with 15 min TTL',
                    Icons.flash_on,
                    Colors.orange,
                  ),
                  const SizedBox(height: 12),
                  _buildRedisMetricsRow(context, provider),
                  
                  const SizedBox(height: 32),
                  
                  // Section: ClickHouse Temperature Time-Series
                  _buildSectionHeader(
                    context,
                    'Temperature Trend (ClickHouse)',
                    'Last 60 minutes from telemetry.events',
                    Icons.thermostat,
                    Colors.blue,
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 250,
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: TemperatureChart(
                          data: provider.temperatureData,
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // Section: ClickHouse Hourly Events
                  _buildSectionHeader(
                    context,
                    'Events per Hour (ClickHouse)',
                    'From materialized view telemetry.events_1h',
                    Icons.bar_chart,
                    Colors.green,
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 250,
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: EventsChart(
                          data: provider.hourlyStats,
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // Section: Device Statistics Table
                  _buildSectionHeader(
                    context,
                    'Device Statistics (ClickHouse)',
                    'Aggregated from telemetry.device_status view',
                    Icons.devices,
                    Colors.purple,
                  ),
                  const SizedBox(height: 12),
                  DeviceTable(devices: provider.deviceStats),
                  
                  const SizedBox(height: 32),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon,
    Color color,
  ) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[400],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRedisMetricsRow(BuildContext context, MetricsProvider provider) {
    final metrics = provider.redisMetrics;
    
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 600;
        
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            SizedBox(
              width: isWide ? (constraints.maxWidth - 24) / 3 : constraints.maxWidth,
              child: MetricCard(
                title: 'Avg Temperature',
                value: '${metrics.avgTemperature.toStringAsFixed(1)}°C',
                subtitle: 'metrics:avg:temperature:5m',
                icon: Icons.thermostat,
                color: _getTemperatureColor(metrics.avgTemperature),
                source: 'Redis',
              ),
            ),
            SizedBox(
              width: isWide ? (constraints.maxWidth - 24) / 3 : constraints.maxWidth,
              child: MetricCard(
                title: 'Avg Pressure',
                value: '${metrics.avgPressure.toStringAsFixed(1)} hPa',
                subtitle: 'metrics:avg:pressure:5m',
                icon: Icons.speed,
                color: Colors.blue,
                source: 'Redis',
              ),
            ),
            SizedBox(
              width: isWide ? (constraints.maxWidth - 24) / 3 : constraints.maxWidth,
              child: MetricCard(
                title: 'Throughput',
                value: '${metrics.throughput.toStringAsFixed(0)} msg/s',
                subtitle: 'metrics:throughput:msg_per_sec',
                icon: Icons.trending_up,
                color: Colors.green,
                source: 'Redis',
              ),
            ),
          ],
        );
      },
    );
  }

  Color _getTemperatureColor(double temp) {
    if (temp > 35) return Colors.red;
    if (temp > 30) return Colors.orange;
    if (temp < 15) return Colors.blue;
    return Colors.teal;
  }
}
