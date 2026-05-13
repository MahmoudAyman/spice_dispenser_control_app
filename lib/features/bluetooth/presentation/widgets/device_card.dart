import 'package:flutter/material.dart';

import '../../data/models/ble_device_model.dart';

class DeviceCard extends StatelessWidget {
  final BleDeviceModel device;
  final VoidCallback onTap;

  const DeviceCard({
    super.key,
    required this.device,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 18),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color:
              Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [

            /// ICON
            Container(
              width: 55,
              height: 55,
              decoration: BoxDecoration(
                color: device.rssi > -60
                    ? const Color(0xFFE8FCEB)
                    : const Color(0xFFF3F4F6),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.bluetooth,
                color: device.rssi > -60
                    ? Colors.green
                    : Colors.grey,
              ),
            ),

            const SizedBox(width: 16),

            /// INFO
            Expanded(
              child: Column(
                crossAxisAlignment:
                CrossAxisAlignment.start,
                children: [
                  Text(
                    device.name,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight:
                      FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 6),

                  Text(
                    'Signal: ${device.rssi} dBm',
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),

            /// PAIRED
            if (device.rssi > -60)
              Container(
                padding:
                const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color:
                  const Color(0xFFE8FCEB),
                  borderRadius:
                  BorderRadius.circular(30),
                ),
                child: const Text(
                  'Paired',
                  style: TextStyle(
                    color: Colors.green,
                    fontWeight:
                    FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}