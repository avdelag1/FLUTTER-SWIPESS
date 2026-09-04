import 'package:cross_file/cross_file.dart';
import 'package:flutter/material.dart';

class ListingVideoNativePreview extends StatelessWidget {
  const ListingVideoNativePreview({
    super.key,
    this.file,
    this.networkUrl,
    required this.muted,
    required this.height,
  });

  final XFile? file;
  final String? networkUrl;
  final bool muted;
  final double height;

  @override
  Widget build(BuildContext context) => SizedBox(height: height);
}
