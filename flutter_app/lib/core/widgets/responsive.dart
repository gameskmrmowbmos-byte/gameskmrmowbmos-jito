import 'package:flutter/material.dart';
import 'package:matka_management/core/constants/app_constants.dart';

enum ScreenClass { mobile, tablet, desktop }

class Responsive {
  Responsive._();

  static ScreenClass classOf(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width < AppConstants.mobileBreakpoint) return ScreenClass.mobile;
    if (width < AppConstants.desktopBreakpoint) return ScreenClass.tablet;
    return ScreenClass.desktop;
  }

  static bool isMobile(BuildContext context) =>
      classOf(context) == ScreenClass.mobile;
  static bool isDesktop(BuildContext context) =>
      classOf(context) == ScreenClass.desktop;
}

class ResponsiveConstrainedBox extends StatelessWidget {
  const ResponsiveConstrainedBox({
    required this.child,
    this.maxWidth = 1400,
    super.key,
  });

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final horizontal = Responsive.isMobile(context) ? 16.0 : 28.0;
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(
          padding: EdgeInsets.fromLTRB(horizontal, 20, horizontal, 32),
          child: child,
        ),
      ),
    );
  }
}
