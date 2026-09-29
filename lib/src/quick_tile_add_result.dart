/// The answer to `QuickControls.requestAddTile`.
enum QuickTileAddResult {
  /// The user accepted and the tile is now in their Quick Settings.
  added,

  /// The tile was already there. The system shows no dialog in this case.
  alreadyAdded,

  /// The user dismissed the dialog.
  notAdded,

  /// Not Android 13 or later, or not Android at all. There is no API to ask
  /// with below 13; the user adds the tile by editing Quick Settings.
  unsupported,

  /// The system refused the request — most often because the app was not in
  /// the foreground, or because the same app asked too recently and the
  /// system is rate-limiting it. Not the user saying no.
  failed;

  /// Maps the native name to a result, treating anything unknown as
  /// [failed] so a new platform code cannot crash the caller.
  static QuickTileAddResult fromName(Object? name) {
    for (final result in values) {
      if (result.name == name) return result;
    }
    return failed;
  }
}
