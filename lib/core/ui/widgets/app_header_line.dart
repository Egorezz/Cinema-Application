import 'package:cinema_app/core/ui/theme/app_colors.dart';
import 'package:flutter/material.dart';

/// 2 px accent line under the header, meant for `AppBar.bottom`.
class AppHeaderLine extends StatelessWidget implements PreferredSizeWidget {
  const AppHeaderLine({super.key});

  static const double height = 2;

  @override
  Size get preferredSize => const Size.fromHeight(height);

  @override
  Widget build(BuildContext context) {
    return Container(height: height, color: AppColors.accent);
  }
}
