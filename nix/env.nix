{ pkgs, packages }:
with packages;
{
  dev = [
    # fastlane powers `pls register` (Apple App Group registration — no ASC API
    # for it, so it needs an App Manager's Apple ID + one 2FA tap, i.e. a human).
    fastlane
    git
    infisical
    pls
  ];

  lint = [
    actionlint
    gitlint
    go-task
    pre-commit
    sg
    shellcheck
    treefmt
  ];

  main = [
  ];

  mobile = [
    flutter
    rsync
    resvg
    # pipx installs codemagic-cli-tools (not in nixpkgs) for the CD signing /
    # publishing / versionCode-query tools (keychain, app-store-connect,
    # xcode-project, google-play).
    pipx
  ]
  # CocoaPods is iOS-only (macOS); keep it off the Linux CI shell.
  ++ pkgs.lib.optionals pkgs.stdenv.isDarwin [
    cocoapods
  ];

  # Android SDK + JDK for local `flutter build apk/appbundle`. Cross-platform
  # (Linux + macOS). Not in the `ci` shell — GitHub CI only lints + tests.
  android = [
    androidsdk
    jdk17
  ];

  releaser = [
    sg
  ];

  system = [
    atomiutils
  ];
}
