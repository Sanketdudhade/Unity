enum BomMappingStatus {
  matched,
  unmatched,
  multipleMatches,
  manuallyMapped;

  String get label {
    switch (this) {
      case BomMappingStatus.matched:
        return 'Matched';
      case BomMappingStatus.unmatched:
        return 'Unmatched';
      case BomMappingStatus.multipleMatches:
        return 'Multiple Matches';
      case BomMappingStatus.manuallyMapped:
        return 'Manually Mapped';
    }
  }

  String toDbString() {
    switch (this) {
      case BomMappingStatus.matched:
        return 'MATCHED';
      case BomMappingStatus.unmatched:
        return 'UNMATCHED';
      case BomMappingStatus.multipleMatches:
        return 'MULTIPLE_MATCHES';
      case BomMappingStatus.manuallyMapped:
        return 'MANUALLY_MAPPED';
    }
  }

  static BomMappingStatus fromString(String? val) {
    switch (val?.toUpperCase()) {
      case 'MATCHED':
        return BomMappingStatus.matched;
      case 'MULTIPLE_MATCHES':
      case 'MULTIPLEMATCHES':
        return BomMappingStatus.multipleMatches;
      case 'MANUALLY_MAPPED':
      case 'MANUALLYMAPPED':
        return BomMappingStatus.manuallyMapped;
      case 'UNMATCHED':
      default:
        return BomMappingStatus.unmatched;
    }
  }
}
