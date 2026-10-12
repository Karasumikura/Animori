import 'package:flutter/material.dart';
import 'package:animori/bean/widget/animori_design.dart';

const double tonalCardRadius = 24;

class TonalCard extends StatelessWidget {
  const TonalCard({
    super.key,
    required this.child,
    this.padding = EdgeInsets.zero,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) =>
      AnimoriPanel(radius: tonalCardRadius, padding: padding, child: child);
}
