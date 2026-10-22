import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../theme.dart';

/// A server photo: sent with the bearer token, cached on disk, and a quiet placeholder until it arrives.
class PhotoImage extends StatelessWidget {
  const PhotoImage({super.key, required this.url, required this.headers, this.fit = BoxFit.cover, this.fadeIn = true});
  final String url;
  final Map<String, String> headers;
  final BoxFit fit;
  final bool fadeIn;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return CachedNetworkImage(
      imageUrl: url,
      httpHeaders: headers,
      cacheKey: url,
      fit: fit,
      fadeInDuration: fadeIn ? const Duration(milliseconds: 200) : Duration.zero,
      placeholder: (_, _) => ColoredBox(color: c.placeholder),
      errorWidget: (_, _, _) => ColoredBox(color: c.placeholder, child: Icon(Icons.broken_image_outlined, color: c.muted)),
    );
  }
}

class Avatar extends StatelessWidget {
  const Avatar({super.key, required this.name, this.photo, this.size = 28});
  final String name;
  final String? photo;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: c.line,
      foregroundImage: photo == null ? null : NetworkImage(photo!),
      child: Text(name.isEmpty ? '?' : name[0].toUpperCase(), style: TextStyle(fontSize: size * .45, color: c.muted, fontWeight: FontWeight.w700)),
    );
  }
}
