import 'package:flutter/material.dart';

import '../../../container_management/data/models/slot_model.dart';

/// Compact two-column grid tile for a single spice slot.
/// Tapping opens the edit/refill bottom sheet.
class SlotGridTile extends StatelessWidget {
  final SlotModel slot;
  final VoidCallback onTap;

  const SlotGridTile({
    super.key,
    required this.slot,
    required this.onTap,
  });

  Color get _levelColor {
    if (slot.level >= 60) return const Color(0xFF22C55E); // green
    if (slot.level >= 30) return const Color(0xFFF59E0B); // amber
    return const Color(0xFFEF4444); // red
  }

  Color get _expiryBadgeColor {
    if (slot.isExpired) return const Color(0xFFEF4444);
    if (slot.isExpiringSoon) return const Color(0xFFF59E0B);
    return Colors.transparent;
  }

  bool get _hasExpiryBadge => slot.isExpired || slot.isExpiringSoon;

  @override
  Widget build(BuildContext context) {
    final bool isEmpty = slot.spiceName.isEmpty;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
          border: _hasExpiryBadge
              ? Border.all(color: _expiryBadgeColor.withOpacity(0.4), width: 1.5)
              : null,
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Slot number + expiry badge row
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: isEmpty
                          ? Colors.grey.shade100
                          : const Color(0xFF2563EB).withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '${slot.slotNumber}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: isEmpty ? Colors.grey.shade400 : const Color(0xFF2563EB),
                        ),
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (_hasExpiryBadge)
                    Tooltip(
                      message: slot.isExpired ? 'Expired' : 'Expires soon',
                      child: Icon(
                        slot.isExpired ? Icons.error : Icons.warning_amber_rounded,
                        size: 18,
                        color: _expiryBadgeColor,
                      ),
                    ),
                  const SizedBox(width: 4),
                  Icon(Icons.chevron_right, size: 18, color: Colors.grey.shade400),
                ],
              ),

              const SizedBox(height: 10),

              // Spice name
              Text(
                isEmpty ? 'Empty' : slot.spiceName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: isEmpty ? Colors.grey.shade400 : Colors.black87,
                ),
              ),

              // Expiry date (only if set)
              if (!isEmpty && slot.expiryDisplayString.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  'Exp: ${slot.expiryDisplayString}',
                  style: TextStyle(
                    fontSize: 11,
                    color: _hasExpiryBadge ? _expiryBadgeColor : Colors.grey.shade500,
                  ),
                ),
              ],

              const Spacer(),

              // Fill level bar
              if (!isEmpty) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Fill',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                    ),
                    Text(
                      '${slot.level}%',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _levelColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: slot.level / 100,
                    minHeight: 6,
                    backgroundColor: Colors.grey.shade100,
                    valueColor: AlwaysStoppedAnimation<Color>(_levelColor),
                  ),
                ),
              ] else ...[
                Text(
                  'Tap to configure',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
