import 'package:flutter/material.dart';

class CameraPlusIcon extends StatelessWidget {
  final double size;
  final Color color;

  const CameraPlusIcon({Key? key, this.size = 24.0, this.color = Colors.black})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Icon(Icons.camera_alt, size: size, color: color),
        Positioned(
          right: 0,
          bottom: 0,
          child: Container(
            padding: const EdgeInsets.all(1),
            decoration: const BoxDecoration(
              color: Colors.red,
              shape: BoxShape.circle,
            ),
            constraints: BoxConstraints(
              minWidth: size * 0.3,
              minHeight: size * 0.3,
            ),
            child: const Center(
              child: Text(
                '+',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
