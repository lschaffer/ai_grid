import 'package:flutter_test/flutter_test.dart';
import 'package:ai_grid/ai_grid.dart';
import 'package:dart_mcp_core/dart_mcp_core.dart';

void main() {
  group('Modular Feature Skill System Tests', () {
    late AiGridController controller;

    setUp(() {
      controller = AiGridController();
    });

    tearDown(() {
      controller.dispose();
    });

    test('AiGridFeatureSkill enum contains all 10 feature skills and core is always active', () {
      expect(AiGridFeatureSkill.values.length, 10);
      expect(AiGridFeatureSkill.core.isAlwaysOn, isTrue);
      expect(AiGridFeatureSkill.pivot.isAlwaysOn, isFalse);
      expect(AiGridFeatureSkill.dataAuditor.isAlwaysOn, isFalse);

      expect(AiGridFeatureSkill.fromId('core'), AiGridFeatureSkill.core);
      expect(AiGridFeatureSkill.fromId('pivot'), AiGridFeatureSkill.pivot);
      expect(AiGridFeatureSkill.fromId('ai_grid_dynamic_grid'), AiGridFeatureSkill.dynamicGrid);
      expect(AiGridFeatureSkill.fromId('card_view'), AiGridFeatureSkill.cardView);
    });

    test('SkillDefinitions map contains complete metadata and tools for all skills', () {
      final defs = AiGridSkill.getSkillDefinitions(controller);
      expect(defs.keys.length, 10);

      final coreDef = defs[AiGridFeatureSkill.core]!;
      expect(coreDef.name, 'core');
      expect(coreDef.isAlwaysOn, isTrue);
      expect(coreDef.tools.any((t) => t.name == 'grid_calculate'), isTrue);

      final pivotDef = defs[AiGridFeatureSkill.pivot]!;
      expect(pivotDef.name, 'pivot');
      expect(pivotDef.tools.any((t) => t.name == 'grid_create_pivot_table'), isTrue);

      final auditorDef = defs[AiGridFeatureSkill.dataAuditor]!;
      expect(auditorDef.name, 'data_auditor');
      expect(auditorDef.tools.any((t) => t.name == 'grid_audit_data'), isTrue);

      final cardDef = defs[AiGridFeatureSkill.cardView]!;
      expect(cardDef.name, 'card_view');
      expect(cardDef.tools.any((t) => t.name == 'grid_set_view_mode'), isTrue);
    });

    test('Selective tool creation filters tools based on activeSkills', () {
      // 1. Only Core + Pivot
      final toolsPivot = AiGridSkill.createTools(
        controller,
        activeSkills: {AiGridFeatureSkill.core, AiGridFeatureSkill.pivot},
        enableDynamicSkillToggling: true,
      );

      final toolNamesPivot = toolsPivot.map((t) => t.name).toSet();
      expect(toolNamesPivot.contains('grid_calculate'), isTrue);
      expect(toolNamesPivot.contains('grid_create_pivot_table'), isTrue);
      expect(toolNamesPivot.contains('grid_audit_data'), isFalse);
      expect(toolNamesPivot.contains('grid_import_excel'), isFalse);
      expect(toolNamesPivot.contains('activate_skills'), isTrue);
      expect(toolNamesPivot.contains('deactivate_skills'), isTrue);

      // 2. Only Core + Data Auditor
      final toolsAuditor = AiGridSkill.createTools(
        controller,
        activeSkills: {AiGridFeatureSkill.core, AiGridFeatureSkill.dataAuditor},
        enableDynamicSkillToggling: false,
      );

      final toolNamesAuditor = toolsAuditor.map((t) => t.name).toSet();
      expect(toolNamesAuditor.contains('grid_calculate'), isTrue);
      expect(toolNamesAuditor.contains('grid_create_pivot_table'), isFalse);
      expect(toolNamesAuditor.contains('grid_audit_data'), isTrue);
      expect(toolNamesAuditor.contains('activate_skills'), isFalse);
    });

    test('Controller active skill toggling and name-based activation works dynamically', () {
      // Set to only Core and SmartColumns
      controller.setActiveSkills([AiGridFeatureSkill.smartColumns]);
      expect(controller.isSkillActive(AiGridFeatureSkill.core), isTrue);
      expect(controller.isSkillActive(AiGridFeatureSkill.smartColumns), isTrue);
      expect(controller.isSkillActive(AiGridFeatureSkill.pivot), isFalse);

      // Activate pivot via activateSkillsByName
      final resActivate = controller.activateSkillsByName(['pivot']);
      expect(resActivate.contains('Pivot & Charts'), isTrue);
      expect(controller.isSkillActive(AiGridFeatureSkill.pivot), isTrue);

      // Deactivate smartColumns via deactivateSkillsByName
      final resDeactivate = controller.deactivateSkillsByName(['smart_columns']);
      expect(resDeactivate.contains('AI Smart Columns'), isTrue);
      expect(controller.isSkillActive(AiGridFeatureSkill.smartColumns), isFalse);

      // Cannot deactivate core
      controller.deactivateSkill(AiGridFeatureSkill.core);
      expect(controller.isSkillActive(AiGridFeatureSkill.core), isTrue);
    });

    test('System prompt dynamically adapts to active skills', () {
      final promptPivotOnly = AiGridSkill.getSystemPrompt(
        activeSkills: {AiGridFeatureSkill.core, AiGridFeatureSkill.pivot},
        includeSkillGuide: true,
      );

      expect(promptPivotOnly.contains('PIVOT MATRIX & CHARTS:'), isTrue);
      expect(promptPivotOnly.contains('DATA QUALITY AUDITING & CLEANING:'), isFalse);
      expect(promptPivotOnly.contains('DYNAMIC SKILL ACTIVATION:'), isTrue);
      expect(promptPivotOnly.contains('`pivot`'), isTrue);

      final promptAuditorOnly = AiGridSkill.getSystemPrompt(
        activeSkills: {AiGridFeatureSkill.core, AiGridFeatureSkill.dataAuditor},
        includeSkillGuide: false,
      );

      expect(promptAuditorOnly.contains('PIVOT MATRIX & CHARTS:'), isFalse);
      expect(promptAuditorOnly.contains('DATA QUALITY AUDITING & CLEANING:'), isTrue);
    });

    test('ActivateSkillsTool and DeactivateSkillsTool MCP execution executes on controller', () async {
      controller.setActiveSkills([AiGridFeatureSkill.core]);
      expect(controller.isSkillActive(AiGridFeatureSkill.excelImport), isFalse);

      final tools = controller.getActiveTools(enableDynamicSkillToggling: true);
      final activateTool = tools.firstWhere((t) => t.name == 'activate_skills') as ActivateSkillsTool;
      final deactivateTool = tools.firstWhere((t) => t.name == 'deactivate_skills') as DeactivateSkillsTool;

      // Execute activate_skills
      final actResult = await activateTool.execute({'skills': ['excel_import']});
      expect(actResult.isError, isFalse);
      expect(controller.isSkillActive(AiGridFeatureSkill.excelImport), isTrue);

      // Execute deactivate_skills
      final deactResult = await deactivateTool.execute({'skills': ['excel_import']});
      expect(deactResult.isError, isFalse);
      expect(controller.isSkillActive(AiGridFeatureSkill.excelImport), isFalse);
    });
  });
}

