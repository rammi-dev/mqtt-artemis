import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/metrics.dart';

class DeviceTable extends StatelessWidget {
  final List<DeviceStats> devices;

  const DeviceTable({super.key, required this.devices});

  @override
  Widget build(BuildContext context) {
    if (devices.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Center(
            child: Text('No device data available'),
          ),
        ),
      );
    }

    return Card(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(
            Colors.grey.withOpacity(0.1),
          ),
          columns: const [
            DataColumn(label: Text('Device ID')),
            DataColumn(label: Text('Type')),
            DataColumn(label: Text('Location')),
            DataColumn(label: Text('Temp (°C)'), numeric: true),
            DataColumn(label: Text('Pressure (hPa)'), numeric: true),
            DataColumn(label: Text('Battery'), numeric: true),
            DataColumn(label: Text('Events'), numeric: true),
            DataColumn(label: Text('Warnings'), numeric: true),
            DataColumn(label: Text('Last Seen')),
          ],
          rows: devices.map((device) {
            return DataRow(
              cells: [
                DataCell(
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _getDeviceIcon(device.deviceType),
                      const SizedBox(width: 8),
                      Text(
                        device.deviceId,
                        style: const TextStyle(fontFamily: 'monospace'),
                      ),
                    ],
                  ),
                ),
                DataCell(_DeviceTypeBadge(type: device.deviceType)),
                DataCell(Text(device.location)),
                DataCell(Text(
                  device.avgTemperature.toStringAsFixed(1),
                  style: TextStyle(
                    color: _getTemperatureColor(device.avgTemperature),
                  ),
                )),
                DataCell(Text(device.avgPressure.toStringAsFixed(1))),
                DataCell(_BatteryIndicator(level: device.batteryLevel)),
                DataCell(Text(device.totalEvents.toString())),
                DataCell(
                  device.warnings > 0
                      ? Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            device.warnings.toString(),
                            style: const TextStyle(
                              color: Colors.orange,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        )
                      : const Text('0'),
                ),
                DataCell(Text(
                  _formatLastSeen(device.lastSeen),
                  style: TextStyle(
                    color: _getLastSeenColor(device.lastSeen),
                  ),
                )),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _getDeviceIcon(String type) {
    IconData icon;
    Color color;
    
    switch (type) {
      case 'temperature-sensor':
        icon = Icons.thermostat;
        color = Colors.red;
        break;
      case 'pressure-sensor':
        icon = Icons.speed;
        color = Colors.blue;
        break;
      case 'multi-sensor':
        icon = Icons.sensors;
        color = Colors.purple;
        break;
      default:
        icon = Icons.device_unknown;
        color = Colors.grey;
    }
    
    return Icon(icon, size: 16, color: color);
  }

  Color _getTemperatureColor(double temp) {
    if (temp > 35) return Colors.red;
    if (temp > 30) return Colors.orange;
    if (temp < 15) return Colors.blue;
    return Colors.white;
  }

  String _formatLastSeen(DateTime lastSeen) {
    final diff = DateTime.now().difference(lastSeen);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return DateFormat('MMM d, HH:mm').format(lastSeen);
  }

  Color _getLastSeenColor(DateTime lastSeen) {
    final diff = DateTime.now().difference(lastSeen);
    if (diff.inMinutes < 5) return Colors.green;
    if (diff.inMinutes < 15) return Colors.yellow;
    return Colors.red;
  }
}

class _DeviceTypeBadge extends StatelessWidget {
  final String type;

  const _DeviceTypeBadge({required this.type});

  @override
  Widget build(BuildContext context) {
    Color color;
    String label;
    
    switch (type) {
      case 'temperature-sensor':
        color = Colors.red;
        label = 'TEMP';
        break;
      case 'pressure-sensor':
        color = Colors.blue;
        label = 'PRESSURE';
        break;
      case 'multi-sensor':
        color = Colors.purple;
        label = 'MULTI';
        break;
      default:
        color = Colors.grey;
        label = type.toUpperCase();
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }
}

class _BatteryIndicator extends StatelessWidget {
  final double level;

  const _BatteryIndicator({required this.level});

  @override
  Widget build(BuildContext context) {
    Color color;
    IconData icon;
    
    if (level > 80) {
      color = Colors.green;
      icon = Icons.battery_full;
    } else if (level > 50) {
      color = Colors.lightGreen;
      icon = Icons.battery_5_bar;
    } else if (level > 20) {
      color = Colors.orange;
      icon = Icons.battery_3_bar;
    } else {
      color = Colors.red;
      icon = Icons.battery_1_bar;
    }
    
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 4),
        Text(
          '${level.toInt()}%',
          style: TextStyle(color: color),
        ),
      ],
    );
  }
}
