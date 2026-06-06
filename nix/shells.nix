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
