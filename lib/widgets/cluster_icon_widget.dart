import 'package:flutter/material.dart';

class ClusterIconWidget extends StatelessWidget {
  final int count;
  final double size;
  final Color color;
  final Color textColor;

  ClusterIconWidget({
    required this.count,
    this.size = 50,
    this.color = Colors.red,
    this.textColor = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: Center(
        child: Text(
          '$count',
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.bold,
            fontSize: size / 2.5,
          ),
        ),
      ),
    );
  }
}
