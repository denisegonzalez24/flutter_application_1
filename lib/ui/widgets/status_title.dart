// lib/ui/widgets/status_tile.dart
import 'package:flutter/material.dart';

class StatusTile extends StatelessWidget {
  final String label;
  final String value;
  final bool monospace;
  const StatusTile({
    super.key,
    required this.label,
    required this.value,
    this.monospace = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text('$label: ', style: const TextStyle(fontWeight: FontWeight.w600)),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontFamily: monospace ? 'monospace' : null,
              color: Colors.black87,
            ),
          ),
        ),
      ],
    );
  }
}
