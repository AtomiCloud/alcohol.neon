{
  atomi,
  pkgs,
  pkgs-2605,
  pkgs-unstable,
  pkgs-flutter,
  pkgs-android,
}:
let
  # codemagic-cli-tools' `xcode-project use-profiles` shells out to ruby and needs the
  # `xcodeproj` gem. The macOS runner's system ruby lacks it, so provide a ruby that has it
  # (shadows /usr/bin/ruby on PATH in the .#cd-ios shell).
  ruby-xcodeproj = pkgs-unstable.ruby.withPackages (ps: [ ps.xcodeproj ]);
  androidComposition = pkgs-android.androidenv.composeAndroidPackages {
    platformVersions = [
      # 31: nfc_manager's compileSdk — gradle can't auto-install into the
      # read-only nix store, so every plugin's platform must be listed here.
      "31"
      "33"
      "34"
      "35"
      "36"
    ];
    buildToolsVersions = [
      "35.0.0"
      "36.0.0"
    ];
    abiVersions = [
      "arm64-v8a"
      "x86_64"
    ];
    includeNDK = true;
    ndkVersions = [ "28.2.13676358" ]; # must match flutter.ndkVersion
    cmakeVersions = [ "3.22.1" ];
    includeEmulator = false;
    includeSystemImages = false;
    extraLicenses = [
      "android-sdk-license"
      "android-sdk-preview-license"
      "android-googletv-license"
      "android-sdk-arm-dbt-license"
      "google-gdk-license"
      "intel-android-extra-license"
      "intel-android-sysimage-license"
      "mips-android-sysimage-license"
    ];
  };
  all = rec {
    atomipkgs = (
      with atomi;
      {
        inherit
          atomiutils
          pls
          sg
          # signing/publishing + store versionCode/build-number queries in the CD
          # shells (keychain, app-store-connect, xcode-project, google-play).
          codemagic-cli-tools
          ;
      }
    );

    nix-2605 = (
      with pkgs-2605;
      {
        inherit
          actionlint
          git
          gitlint
          go-task
          infisical
          pre-commit
          shellcheck
          treefmt
          rsync
          resvg
          jdk17
          # protoc + bundletool power scripts/ci/stamp-android.sh (re-badge the
          # single built AAB per landscape) and its doctor assertions.
          protobuf
          bundletool
          # mikefarah yq (v4) — reads lpsm.yaml (cd-matrix.sh, register-apple.sh,
          # lpsm-lint pre-commit hook).
          yq-go
          ;
      }
    );

    nix-unstable = (
      with pkgs-unstable;
      {
        flutter = pkgs-flutter.flutter347;
        inherit
          cocoapods
          # fastlane: only for `pls register` (scripts/register-apple.sh) — App Group
          # creation/association has no App Store Connect API, so it rides Spaceship's
          # Apple-ID (2FA) portal client. Dev shell only; CI/CD stays API-key-based.
          fastlane
          ;
      }
    );

    nix-android = {
      androidsdk = androidComposition.androidsdk;
      # Local Android 16 emulator for development (`pls emulator`). Kept out of
      # every shell so the dev and CI closures don't pull in system images.
      # The device lives in ~/.android/neon, so installed apps survive restarts.
      android-emulator = pkgs-android.writeShellScriptBin "android-emulator" ''
        # Pixel-sized screen (1080x2400, 420dpi); without a device profile the
        # AVD gets 320x640@160dpi and looks blurry. Only read when the AVD is
        # first created: delete ~/.android/neon/avd/neon_pixel.avd to apply.
        export NIX_ANDROID_AVD_FLAGS="--device pixel_6"
        exec ${
          pkgs-android.androidenv.emulateApp {
            name = "neon-android-emulator";
            platformVersion = "36";
            abiVersion = "arm64-v8a";
            systemImageType = "google_apis";
            deviceName = "neon_pixel";
            androidUserHome = "$HOME/.android/neon";
            configOptions = {
              "hw.gpu.enabled" = "yes";
              "hw.gpu.mode" = "host";
              "hw.keyboard" = "yes";
            };
          }
        }/bin/run-test-emulator "$@"
      '';
    };
  };
in
with all;
atomipkgs // nix-2605 // nix-unstable // nix-android // { inherit ruby-xcodeproj; }
