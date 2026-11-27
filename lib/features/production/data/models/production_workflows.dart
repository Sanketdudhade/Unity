import 'package:unity/features/processes/data/models/process_step_model.dart';

/// Centralized configuration of standard production workflows: CUTTING and NON-CUTTING.
class ProductionWorkflows {
  ProductionWorkflows._();

  static const String cutting = 'CUTTING';
  static const String nonCutting = 'NON_CUTTING';

  /// Sequence of 14 stages for CUTTING workflow:
  /// 1. BOM
  /// 2. Material Order Date
  /// 3. Raw Material
  /// 4. M&G (Milling & Grinding)
  /// 5. DWG (Drawing)
  /// 6. Pillar / Bush / Button
  /// 7. DRO
  /// 8. ASY (Assembly)
  /// 9. H/T (Heat Treatment)
  /// 10. VMC
  /// 11. W/C (Wire Cutting)
  /// 12. F.ASY (Final Assembly)
  /// 13. Trial
  /// 14. Tool Final Date
  static List<ProcessStepModel> cuttingStages() {
    return const [
      ProcessStepModel(id: 'cut_1', sequence: 1, name: 'BOM', defaultDurationHours: 8, dependsOnStepSequence: []),
      ProcessStepModel(id: 'cut_2', sequence: 2, name: 'Material Order Date', defaultDurationHours: 8, dependsOnStepSequence: [1]),
      ProcessStepModel(id: 'cut_3', sequence: 3, name: 'Raw Material', defaultDurationHours: 16, dependsOnStepSequence: [2]),
      ProcessStepModel(id: 'cut_4', sequence: 4, name: 'M&G (Milling & Grinding)', defaultDurationHours: 24, dependsOnStepSequence: [3]),
      ProcessStepModel(id: 'cut_5', sequence: 5, name: 'DWG (Drawing)', defaultDurationHours: 16, dependsOnStepSequence: [4]),
      ProcessStepModel(id: 'cut_6', sequence: 6, name: 'Pillar / Bush / Button', defaultDurationHours: 16, dependsOnStepSequence: [5]),
      ProcessStepModel(id: 'cut_7', sequence: 7, name: 'DRO', defaultDurationHours: 16, dependsOnStepSequence: [6]),
      ProcessStepModel(id: 'cut_8', sequence: 8, name: 'ASY (Assembly)', defaultDurationHours: 24, dependsOnStepSequence: [7]),
      ProcessStepModel(id: 'cut_9', sequence: 9, name: 'H/T (Heat Treatment)', defaultDurationHours: 24, dependsOnStepSequence: [8]),
      ProcessStepModel(id: 'cut_10', sequence: 10, name: 'VMC', defaultDurationHours: 32, dependsOnStepSequence: [9]),
      ProcessStepModel(id: 'cut_11', sequence: 11, name: 'W/C (Wire Cutting)', defaultDurationHours: 24, dependsOnStepSequence: [10]),
      ProcessStepModel(id: 'cut_12', sequence: 12, name: 'F.ASY (Final Assembly)', defaultDurationHours: 16, dependsOnStepSequence: [11]),
      ProcessStepModel(id: 'cut_13', sequence: 13, name: 'Trial', defaultDurationHours: 8, dependsOnStepSequence: [12]),
      ProcessStepModel(id: 'cut_14', sequence: 14, name: 'Tool Final Date', defaultDurationHours: 8, dependsOnStepSequence: [13]),
    ];
  }

  /// Sequence of 15 stages for NON-CUTTING workflow:
  /// 1. BOM
  /// 2. Material Order Date
  /// 3. Raw Material
  /// 4. M&G (Milling & Grinding)
  /// 5. DWG (Drawing)
  /// 6. Pillar / Bush / Button
  /// 7. DRO
  /// 8. ASY (Assembly)
  /// 9. VMC
  /// 10. Machine / Drawing Operation
  /// 11. W/C (Wire Cutting)
  /// 12. F.ASY (Final Assembly)
  /// 13. Trial
  /// 14. H/T (Heat Treatment)
  /// 15. Tool Final Date
  static List<ProcessStepModel> nonCuttingStages() {
    return const [
      ProcessStepModel(id: 'ncut_1', sequence: 1, name: 'BOM', defaultDurationHours: 8, dependsOnStepSequence: []),
      ProcessStepModel(id: 'ncut_2', sequence: 2, name: 'Material Order Date', defaultDurationHours: 8, dependsOnStepSequence: [1]),
      ProcessStepModel(id: 'ncut_3', sequence: 3, name: 'Raw Material', defaultDurationHours: 16, dependsOnStepSequence: [2]),
      ProcessStepModel(id: 'ncut_4', sequence: 4, name: 'M&G (Milling & Grinding)', defaultDurationHours: 24, dependsOnStepSequence: [3]),
      ProcessStepModel(id: 'ncut_5', sequence: 5, name: 'DWG (Drawing)', defaultDurationHours: 16, dependsOnStepSequence: [4]),
      ProcessStepModel(id: 'ncut_6', sequence: 6, name: 'Pillar / Bush / Button', defaultDurationHours: 16, dependsOnStepSequence: [5]),
      ProcessStepModel(id: 'ncut_7', sequence: 7, name: 'DRO', defaultDurationHours: 16, dependsOnStepSequence: [6]),
      ProcessStepModel(id: 'ncut_8', sequence: 8, name: 'ASY (Assembly)', defaultDurationHours: 24, dependsOnStepSequence: [7]),
      ProcessStepModel(id: 'ncut_9', sequence: 9, name: 'VMC', defaultDurationHours: 32, dependsOnStepSequence: [8]),
      ProcessStepModel(id: 'ncut_10', sequence: 10, name: 'Machine / Drawing Operation', defaultDurationHours: 24, dependsOnStepSequence: [9]),
      ProcessStepModel(id: 'ncut_11', sequence: 11, name: 'W/C (Wire Cutting)', defaultDurationHours: 24, dependsOnStepSequence: [10]),
      ProcessStepModel(id: 'ncut_12', sequence: 12, name: 'F.ASY (Final Assembly)', defaultDurationHours: 16, dependsOnStepSequence: [11]),
      ProcessStepModel(id: 'ncut_13', sequence: 13, name: 'Trial', defaultDurationHours: 8, dependsOnStepSequence: [12]),
      ProcessStepModel(id: 'ncut_14', sequence: 14, name: 'H/T (Heat Treatment)', defaultDurationHours: 24, dependsOnStepSequence: [13]),
      ProcessStepModel(id: 'ncut_15', sequence: 15, name: 'Tool Final Date', defaultDurationHours: 8, dependsOnStepSequence: [14]),
    ];
  }

  /// Returns the corresponding step models for a given production type.
  static List<ProcessStepModel> getStages(String productionType) {
    if (productionType.toUpperCase() == nonCutting) {
      return nonCuttingStages();
    }
    return cuttingStages();
  }

  /// Returns the number of stages in the workflow.
  static int getStageCount(String productionType) {
    if (productionType.toUpperCase() == nonCutting) {
      return 15;
    }
    return 14;
  }

  /// Returns user-friendly title for the workflow.
  static String getLabel(String productionType) {
    if (productionType.toUpperCase() == nonCutting) {
      return 'Non-Cutting (15 Stages)';
    }
    return 'Cutting (14 Stages)';
  }
}
