/// The answer to `QuickControls.requestAddTile`.
enum QuickTileAddResult {
  /// The user accepted and the tile is now in their Quick Settings.
  added,

  /// The tile was already there.
  ///
  /// The system shows no dialog in this case.
  alreadyAdded,

  /// The user dismissed the dialog.
  notAdded,

  /// Not Android 13 or later, or not Android at all.
  ///
  /// There is no API to ask with below 13; the user adds the tile by editing
  /// Quick Settings.
  unsupported,

  /// The system refused the request; not the user saying no.
  ///
  /// Most often because the app was not in the foreground, or because the
  /// same app asked too recently and the system is rate-limiting it.
  failed,
}

/// Maps the native name to a result, treating anything unknown as
/// [QuickTileAddResult.failed] so a new platform code cannot crash the
/// caller.
///
/// Wire format, so not exported.
QuickTileAddResult quickTileAddResultNamed(Object? name) {
  for (final result in QuickTileAddResult.values) {
    if (result.name == name) return result;
  }
  return QuickTileAddResult.failed;
}
