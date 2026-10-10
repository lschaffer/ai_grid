import 'package:flutter/material.dart';
import 'package:trina_grid/trina_grid.dart';

/// Provides theme configurations for [AiGrid].
///
/// Supports automatic derivation from the host app's [ThemeData] (light & dark mode),
/// as well as the standard Fluent theme.
class AiGridTheme {
  AiGridTheme._();

  static const Color primaryBlue = Color(0xFF0078D4);
  static const Color backgroundLight = Color(0xFFFFFFFF);
  static const Color headerBackground = Color(0xFFF8FAFC);
  static const Color groupPanelBackground = Color(0xFFF1F5F9);
  static const Color borderColor = Color(0xFFE2E8F0);
  static const Color activatedBorderColor = Color(0xFF0078D4);
  static const Color textColor = Color(0xFF1E293B);
  static const Color textMuted = Color(0xFF64748B);
  static const Color rowHoverColor = Color(0xFFF0F7FF);
  static const Color chipBackground = Color(0xFFFFFFFF);

  /// Automatically derives a [TrinaGridConfiguration] from the parent app's [ThemeData].
  ///
  /// Seamlessly adapts to Dark Mode, Light Mode, and custom brand colors.
  static TrinaGridConfiguration createThemeFromContext(
    BuildContext context, {
    bool showColumnFilter = true,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colorScheme = theme.colorScheme;

    final bgColor = isDark ? colorScheme.surface : Colors.white;
    final oddRowColor = isDark
        ? colorScheme.surfaceContainer
        : const Color(0xFFFAFAFA);
    final gridBorder = isDark
        ? colorScheme.outlineVariant.withAlpha(80)
        : borderColor;
    final txtColor = colorScheme.onSurface;
    final headerBg = isDark
        ? colorScheme.surfaceContainerHighest
        : const Color(0xFFF8FAFC);

    return TrinaGridConfiguration(
      style: TrinaGridStyleConfig(
        gridBackgroundColor: bgColor,
        rowColor: bgColor,
        oddRowColor: bgColor,
        evenRowColor: oddRowColor,
        borderColor: gridBorder,
        activatedBorderColor: colorScheme.primary,
        inactivatedBorderColor: gridBorder,
        columnTextStyle: TextStyle(
          color: txtColor,
          fontSize: 13,
          fontWeight: FontWeight.w600,
          fontFamily: theme.textTheme.bodyMedium?.fontFamily ?? 'Segoe UI',
        ),
        cellTextStyle: TextStyle(
          color: txtColor,
          fontSize: 13,
          fontFamily: theme.textTheme.bodyMedium?.fontFamily ?? 'Segoe UI',
        ),
        columnHeight: 44,
        rowHeight: 40,
        columnFilterHeight: 38,
        filterHeaderColor: headerBg,
        defaultColumnFilterPadding: const EdgeInsets.symmetric(
          horizontal: 6,
          vertical: 3,
        ),
        enableColumnBorderVertical: true,
        enableColumnBorderHorizontal: true,
        enableCellBorderVertical: true,
        enableCellBorderHorizontal: true,
      ),
      columnFilter: TrinaGridColumnFilterConfig(
        filters: FilterHelper.defaultFilters,
      ),
    );
  }

  /// Creates a standard Fluent-style [TrinaGridConfiguration].
  static TrinaGridConfiguration createFluentConfiguration({
    bool showColumnFilter = true,
  }) {
    return TrinaGridConfiguration(
      style: const TrinaGridStyleConfig(
        gridBackgroundColor: backgroundLight,
        rowColor: backgroundLight,
        oddRowColor: backgroundLight,
        evenRowColor: Color(0xFFFAFAFA),
        borderColor: borderColor,
        activatedBorderColor: activatedBorderColor,
        inactivatedBorderColor: borderColor,
        columnTextStyle: TextStyle(
          color: textColor,
          fontSize: 13,
          fontWeight: FontWeight.w600,
          fontFamily: 'Segoe UI',
        ),
        cellTextStyle: TextStyle(
          color: textColor,
          fontSize: 13,
          fontFamily: 'Segoe UI',
        ),
        columnHeight: 44,
        rowHeight: 40,
        columnFilterHeight: 38,
        filterHeaderColor: Color(0xFFF8FAFC),
        defaultColumnFilterPadding: EdgeInsets.symmetric(
          horizontal: 6,
          vertical: 3,
        ),
        enableColumnBorderVertical: true,
        enableColumnBorderHorizontal: true,
        enableCellBorderVertical: true,
        enableCellBorderHorizontal: true,
      ),
      columnFilter: TrinaGridColumnFilterConfig(
        filters: FilterHelper.defaultFilters,
      ),
    );
  }
}
