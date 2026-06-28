import 'package:flutter/material.dart';

import '../constants/app_assets.dart';
import '../constants/colors.dart';
import 'app_image.dart';

/// Avatar profil : photo locale ou initiale du nom.
class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({
    super.key,
    required this.name,
    this.radius = 22,
    this.imagePath,
  });

  final String name;
  final double radius;
  final String? imagePath;

  @override
  Widget build(BuildContext context) {
    final asset = imagePath ?? AppAssets.profileDefault;
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final size = radius * 2;

    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.redTint,
      child: ClipOval(
        child: AppImage(
          asset: asset,
          width: size,
          height: size,
          fit: BoxFit.cover,
          placeholder: Center(
            child: Text(
              initial,
              style: TextStyle(
                color: AppColors.primaryRed,
                fontWeight: FontWeight.w800,
                fontSize: radius * 0.85,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
