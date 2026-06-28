import 'package:flutter/material.dart';

import '../constants/colors.dart';

/// Image locale fiable (assets/images) avec redimensionnement pour mobile.
class AppImage extends StatelessWidget {
  const AppImage({
    super.key,
    required this.asset,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.placeholder,
  });

  final String asset;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final Widget? placeholder;

  static int? _cacheWidthFor(double? logicalWidth) {
    if (logicalWidth == null || !logicalWidth.isFinite || logicalWidth <= 0) {
      return 800;
    }
    return (logicalWidth * 2).round().clamp(200, 1200);
  }

  Widget _buildImage({double? layoutWidth}) {
    final image = Image.asset(
      asset,
      width: width?.isFinite == true ? width : null,
      height: height?.isFinite == true ? height : null,
      fit: fit,
      cacheWidth: _cacheWidthFor(layoutWidth ?? width),
      gaplessPlayback: true,
      filterQuality: FilterQuality.medium,
      errorBuilder: (_, __, ___) =>
          placeholder ??
          Container(
            width: width?.isFinite == true ? width : layoutWidth,
            height: height?.isFinite == true ? height : null,
            color: AppColors.redTint,
            alignment: Alignment.center,
            child: const Icon(
              Icons.image_outlined,
              color: AppColors.primaryRed,
            ),
          ),
    );

    if (borderRadius == null) return image;
    return ClipRRect(borderRadius: borderRadius!, child: image);
  }

  @override
  Widget build(BuildContext context) {
    final hasFiniteWidth = width != null && width!.isFinite;

    if (hasFiniteWidth) {
      return _buildImage();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final layoutWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        return _buildImage(layoutWidth: layoutWidth);
      },
    );
  }
}
