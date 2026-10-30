import 'package:flutter/widgets.dart';

/// Available layout presentation modes for [AiGrid].
enum AiGridViewMode {
  /// Standard high-performance canvas DataGrid view.
  grid,

  /// Responsive card / feed list view optimized for mobile devices and content scanning.
  card,
}

/// Configuration options for the responsive Card / Feed view in [AiGrid].
class AiGridCardViewOptions {
  /// Field name to display as the primary title of each card.
  /// If omitted, falls back to the first non-action text column.
  final String? primaryField;

  /// Optional field name to display as the secondary subtitle.
  final String? subtitleField;

  /// Optional field name to display as a category / status badge pill in the header.
  final String? badgeField;

  /// Optional field name providing an avatar or thumbnail image URL / asset.
  final String? avatarField;

  /// Column fields to exclude from the card's key-value body.
  final Set<String> excludedFields;

  /// Whether swipe gestures (swipe-to-edit, swipe-to-delete) are enabled on cards.
  final bool enableSwipeActions;

  /// Elevation of each card.
  final double elevation;

  /// Border radius of each card.
  final BorderRadius? borderRadius;

  /// Content padding inside each card.
  final EdgeInsetsGeometry contentPadding;

  /// Spacing between cards in the list.
  final double spacing;

  /// Optional custom card widget builder override.
  final Widget Function(
    BuildContext context,
    Map<String, dynamic> row,
    int rowIndex,
  )?
  cardBuilder;

  const AiGridCardViewOptions({
    this.primaryField,
    this.subtitleField,
    this.badgeField,
    this.avatarField,
    this.excludedFields = const {},
    this.enableSwipeActions = true,
    this.elevation = 1.0,
    this.borderRadius,
    this.contentPadding = const EdgeInsets.all(14.0),
    this.spacing = 10.0,
    this.cardBuilder,
  });

  AiGridCardViewOptions copyWith({
    String? primaryField,
    String? subtitleField,
    String? badgeField,
    String? avatarField,
    Set<String>? excludedFields,
    bool? enableSwipeActions,
    double? elevation,
    BorderRadius? borderRadius,
    EdgeInsetsGeometry? contentPadding,
    double? spacing,
    Widget Function(
      BuildContext context,
      Map<String, dynamic> row,
      int rowIndex,
    )?
    cardBuilder,
  }) {
    return AiGridCardViewOptions(
      primaryField: primaryField ?? this.primaryField,
      subtitleField: subtitleField ?? this.subtitleField,
      badgeField: badgeField ?? this.badgeField,
      avatarField: avatarField ?? this.avatarField,
      excludedFields: excludedFields ?? this.excludedFields,
      enableSwipeActions: enableSwipeActions ?? this.enableSwipeActions,
      elevation: elevation ?? this.elevation,
      borderRadius: borderRadius ?? this.borderRadius,
      contentPadding: contentPadding ?? this.contentPadding,
      spacing: spacing ?? this.spacing,
      cardBuilder: cardBuilder ?? this.cardBuilder,
    );
  }
}
