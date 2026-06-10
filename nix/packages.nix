{
  atomi,
  pkgs,
  pkgs-2605,
  pkgs-unstable,
  pkgs-android,
}:
let
  # pipx 1.8.0 in nixpkgs currently fails its test suite (a `packaging`-lib
  # formatting regression in tests/test_package_specifier.py, not a runtime bug),
  # which breaks the build on darwin. Skip the test phase — we only need the CLI.
  pipx = pkgs-2605.pipx.overridePythonAttrs (_: {
    doCheck = false;
    doInstallCheck = false;
  });
  androidComposition = pkgs-android.androidenv.composeAndroidPackages {
    platformVersions = [
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
          ;
      }
      // {
        # pipx with its broken test phase disabled (see top of file).
        inherit pipx;
      }
    );

    nix-unstable = (
      with pkgs-unstable;
      {
        inherit
          flutter
          cocoapods
          ;
      }
    );

    nix-android = {
      androidsdk = androidComposition.androidsdk;
    };
  };
in
with all;
atomipkgs // nix-2605 // nix-unstable // nix-android
