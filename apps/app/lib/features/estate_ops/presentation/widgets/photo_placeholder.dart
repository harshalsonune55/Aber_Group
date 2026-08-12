import 'package:flutter/material.dart';

/// Stand-in for a listing photo — used while a listing is unphotographed, and
/// as the fallback when an image fails to decode.
class PhotoPlaceholder extends StatelessWidget {
  const PhotoPlaceholder({super.key, required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      height: height,
      width: double.infinity,
      alignment: Alignment.center,
      color: scheme.surfaceContainerHigh,
      child: Icon(
        Icons.image_outlined,
        size: 28,
        color: scheme.onSurfaceVariant.withValues(alpha: 0.5),
      ),
    );
  }
}

/// A listing photo, falling back to [PhotoPlaceholder].
///
/// Listings without a photo, and photos that fail to decode, both land on the
/// placeholder rather than Flutter's grey broken-image box — a listing with a
/// bad asset should still look like a listing. Images are bundled assets for
/// now; when photos move to a CDN this is the one widget that changes.
class ListingPhoto extends StatelessWidget {
  const ListingPhoto({
    super.key,
    required this.asset,
    required this.height,
    this.darken = true,
  });

  final String? asset;
  final double height;

  /// Lays a subtle gradient over the lower edge so overlaid text stays legible
  /// against a bright photo.
  final bool darken;

  @override
  Widget build(BuildContext context) {
    final path = asset;
    if (path == null) return PhotoPlaceholder(height: height);

    return SizedBox(
      height: height,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            path,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => PhotoPlaceholder(height: height),
          ),
          if (darken)
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.28),
                  ],
                  stops: const [0.55, 1.0],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
