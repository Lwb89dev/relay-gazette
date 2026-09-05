/// The reader's chosen look. `system` follows the OS light/dark setting;
/// the other three are explicit choices that override it.
enum ThemePreference { system, light, dark, sport }

/// Whether body copy renders in the editorial serif (the default,
/// newspaper-like) or a plain sans-serif for readers who find serif body
/// text harder to read. Headlines stay serif either way — it's a
/// masthead/identity choice, not a readability one.
enum BodyFontPreference { serif, sansSerif }
