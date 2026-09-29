# quick_controls example

A counter (`rows`), a toggle (`light`) and a button (`ping`). On Android, the
button opens the app. The app drains on launch and on resume, listens while
open, and publishes the new values.

`ios/ExampleControls` is a real widget extension target that compiles
`QuickControlsKit` from `../ios/quick_controls/Sources/QuickControlsKit` by
reference. It is the worked version of the README's iOS setup steps. Its
deployment target is iOS 17, with the controls behind `#available(iOS 18.0,
*)`, to prove the kit fits in an extension that also serves older widgets.

The App Group `group.com.illuminationdevelopment.quickcontrols.example` is
not registered with Apple. Simulator builds work without it; a device build
will not sign until it is registered.
