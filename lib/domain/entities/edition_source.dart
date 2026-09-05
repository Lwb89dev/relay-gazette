/// Where an edition's stories were drawn from. `trending` is the Phase 2
/// discovery mode (backed by Primal or similar); `customList` draws from a
/// NIP-51 follow set instead of the reader's entire contact list. The
/// reader UI never needs to know which provider actually served the
/// stories.
enum EditionSource {
  personalNetwork,
  trending,
  customList;

  String get label => switch (this) {
    EditionSource.personalNetwork => 'From Your Network',
    EditionSource.trending => 'Trending',
    EditionSource.customList => 'From a List',
  };
}
