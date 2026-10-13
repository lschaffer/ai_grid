import 'package:material_ui/material_ui.dart';
import '../fitgrid/fitgrid_table.dart';

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

  /// Automatically derives a [FitGridThemeData] from the parent app's [ThemeData].
  ///
  /// Seamlessly adapts to Dark Mode, Light Mode, and custom brand colors.
  static FitGridThemeData createThemeFromContext(
    BuildContext context, {
    FitGridDensity density = FitGridDensity.standard,
  }) {
    final theme = Theme.of(context);
    return FitGridThemeData.fromTheme(theme, density: density);
  }

  /// Creates a standard Fluent-style [FitGridThemeData].
  static FitGridThemeData createFluentConfiguration({
    FitGridDensity density = FitGridDensity.standard,
  }) {
    final divider = borderColor;

    return FitGridThemeData(
      headerBackground: headerBackground,
      headerForeground: textColor,
      headerTextStyle: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: textColor,
        fontFamily: 'Segoe UI',
      ),
      rowBackground: backgroundLight,
      alternateRowBackground: const Color(0xFFFAFAFA),
      cellTextStyle: const TextStyle(
        fontSize: 13,
        color: textColor,
        fontFamily: 'Segoe UI',
      ),
      rowDivider: divider,
      columnDivider: divider,
      border: divider,
      hoverBackground: rowHoverColor,
      selectedBackground: const Color(0xFFE5F1FB),
      focusOutline: activatedBorderColor,
      sortIconColor: textMuted,
      placeholderForeground: textMuted,
      tooltipBackground: const Color(0xFF2D3748),
      tooltipForeground: Colors.white,
      searchHighlight: const Color(0xFFFFE082),
      frozenShadow: Colors.black.withAlpha(20),
      groupHeaderBackground: groupPanelBackground,
      density: density,
    );
  }
}
