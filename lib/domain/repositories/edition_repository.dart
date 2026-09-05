import '../entities/edition_summary.dart';
import '../entities/gazette_edition.dart';

/// Local, offline-first persistence for generated editions. Once an edition
/// is saved, reading it back must never require network access.
abstract class EditionRepository {
  Future<void> save(GazetteEdition edition);

  Future<GazetteEdition?> getById(String id);

  /// Newest-first listing for the archive shelf.
  Future<List<GazetteEditionSummary>> getAllSummaries();

  Future<void> delete(String id);
}
