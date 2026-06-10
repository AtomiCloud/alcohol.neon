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
    # flutter + CocoaPods (darwin) + GNU rsync + pipx. iOS builds go through
    # scripts/flutter-ios.sh, which un-hijacks the nix C/C++ toolchain for xcodebuild.
    buildInputs = mobile ++ system;
    inherit shellHook;
  };

  cd-android = pkgs.mkShell {
    buildInputs = mobile ++ android ++ system;
    inherit shellHook;
    ANDROID_SDK_ROOT = "${packages.androidsdk}/libexec/android-sdk";
    ANDROID_HOME = "${packages.androidsdk}/libexec/android-sdk";
    JAVA_HOME = "${packages.jdk17.home}";
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
