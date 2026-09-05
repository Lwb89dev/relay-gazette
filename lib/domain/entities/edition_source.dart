/// Where an edition's stories were drawn from. `trending` is the Phase 2
/// discovery mode (backed by Primal or similar); `customList` draws from a
/// NIP-51 follow set instead of the reader's entire contact list;
/// `webOfTrust` draws from content the reader's wider network (not just
/// direct follows) has engaged with — Primal's "My Network Interactions"
/// scope, the closest practical Web-of-Trust signal available without the
/// client computing its own follow graph. The reader UI never needs to
/// know which provider actually served the stories.
enum EditionSource {
  personalNetwork,
  trending,
  customList,
  webOfTrust;

  String get label => switch (this) {
    EditionSource.personalNetwork => 'From Your Network',
    EditionSource.trending => 'Trending',
    EditionSource.customList => 'From a List',
    EditionSource.webOfTrust => 'Web of Trust',
  };
}
