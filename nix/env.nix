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
    cocoapods
    rsync
    resvg
  ];

  releaser = [
    sg
  ];

  system = [
    atomiutils
  ];
}
