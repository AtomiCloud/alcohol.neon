{ pkgs, packages }:
with packages;
{
  dev = [
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
