{
  env,
  packages,
  pkgs,
  shellHook,
}:
with env;
{
  cd = pkgs.mkShell {
    buildInputs = main ++ system;
    inherit shellHook;
  };

  # Mobile CD shells (used by .github/workflows/cd.yaml via AtomiCloud/actions.setup-nix
  # so the toolchain comes from the shared nix store cache). Split per platform so the
  # macOS iOS runner doesn't pull the Android SDK closure.
  cd-ios = pkgs.mkShell {
    # flutter + CocoaPods (darwin) + GNU rsync + pipx, plus a ruby carrying the xcodeproj
    # gem (codemagic's `xcode-project use-profiles` needs it; system ruby lacks it). iOS
    # builds go through scripts/flutter-ios.sh, which un-hijacks the nix C/C++ toolchain.
    buildInputs = mobile ++ system ++ [ packages.ruby-xcodeproj ];
    inherit shellHook;
  };

  cd-android = pkgs.mkShell {
    buildInputs = mobile ++ android ++ system;
    inherit shellHook;
    ANDROID_SDK_ROOT = "${packages.androidsdk}/libexec/android-sdk";
    ANDROID_HOME = "${packages.androidsdk}/libexec/android-sdk";
    JAVA_HOME = "${packages.jdk17.home}";
  };

  # Donor AAB build (⚡reusable-build-android.yaml → scripts/ci/cd-android.sh): only
  # `flutter pub get` + `flutter build appbundle`. Skips everything cd-android adds for
  # stamping/uploading (now the publish-android job's), atomiutils, rsync/resvg, the nix
  # C toolchain (the NDK brings its own clang) and the pre-commit shellHook — the cold
  # download of those from the cache was eating the job's timeout before Gradle started.
  build-android = pkgs.mkShellNoCC {
    buildInputs = [
      packages.flutter
      packages.androidsdk
      packages.jdk17
    ];
    ANDROID_SDK_ROOT = "${packages.androidsdk}/libexec/android-sdk";
    ANDROID_HOME = "${packages.androidsdk}/libexec/android-sdk";
    JAVA_HOME = "${packages.jdk17.home}";
  };

  # Store-upload shells (⚡reusable-publish-*.yaml). Those jobs only stamp and re-sign an
  # already-built donor, so they skip Flutter, the Android SDK/NDK, CocoaPods, atomiutils
  # (1.7 GiB, for yq alone), the C toolchain and the pre-commit shellHook. Downloading those
  # from the cache made every upload job hit its timeout before it reached the upload.
  # zip/unzip come from the runner, like in the cd-* shells.
  publish-ios = pkgs.mkShellNoCC {
    # keychain + app-store-connect (codemagic). PlistBuddy, codesign and security are macOS's.
    buildInputs = [
      packages.codemagic-cli-tools
      packages.yq-go
    ];
  };

  publish-android = pkgs.mkShellNoCC {
    # google-play (codemagic), protoc + bundletool (stamp-android.sh), jarsigner.
    buildInputs = [
      packages.codemagic-cli-tools
      packages.yq-go
      packages.protobuf
      packages.bundletool
      pkgs.jdk17_headless
    ];
    JAVA_HOME = "${pkgs.jdk17_headless.home}";
  };

  ci = pkgs.mkShell {
    buildInputs = lint ++ main ++ mobile ++ system;
    inherit shellHook;
  };

  default = pkgs.mkShell {
    buildInputs = dev ++ lint ++ main ++ mobile ++ android ++ system;
    inherit shellHook;
    ANDROID_SDK_ROOT = "${packages.androidsdk}/libexec/android-sdk";
    ANDROID_HOME = "${packages.androidsdk}/libexec/android-sdk";
    JAVA_HOME = "${packages.jdk17.home}";
  };

  releaser = pkgs.mkShell {
    buildInputs = lint ++ main ++ releaser ++ system;
    inherit shellHook;
  };
}
