import 'package:flutter/material.dart';

/// Descriptor para los widgets modulares disponibles en el Dashboard
class DashboardWidgetItem {
  final String id;
  final String title;
  final String description;
  final String categoryTag;
  final Widget previewMockup;
  final bool isDefaultVisible;
  final bool isComingSoon;

  const DashboardWidgetItem({
    required this.id,
    required this.title,
    required this.description,
    required this.categoryTag,
    required this.previewMockup,
    this.isDefaultVisible = true,
    this.isComingSoon = false,
  });
}
