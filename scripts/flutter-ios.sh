#!/usr/bin/env bash
set -euo pipefail

# Run Flutter iOS builds from inside the nix dev shell.
#
# The nix dev shell is a full C/C++ stdenv, so it exports a toolchain that
# hijacks Xcode's iOS build:
#   - DEVELOPER_DIR  -> a nix apple-sdk (not real Xcode)
#   - SDKROOT        -> the macOS SDK (wrong platform for an iOS build)
#   - CC/CXX/LD + NIX_CFLAGS_COMPILE/NIX_LDFLAGS -> nix clang/ld wrappers
# xcodebuild inherits these and the nix linker rejects Apple's flags:
#   "Unknown options: -Xlinker -dynamiclib ... -fobjc-arc -fobjc-link-runtime"
# The shell also drops /usr/bin from xcrun's fallback search, which surfaces as
#   "tool 'osascript' not found" during the install/launch step.
#
# This wrapper strips the nix toolchain vars, points DEVELOPER_DIR at the real
# Xcode, and restores the system PATH, so xcodebuild uses Apple's clang/ld/SDK.
# `flutter` itself still comes from the nix PATH (device detection needs it).
#
# Usage (from the direnv/nix shell):
#   scripts/flutter-ios.sh run -d <device-id>
#   scripts/flutter-ios.sh build ipa
#   scripts/flutter-ios.sh build ios --debug --simulator
# Override the Xcode location with DEVELOPER_DIR_OVERRIDE if needed.

# Drop every nix-injected compiler/linker var (NIX_CC, NIX_LDFLAGS, NIX_*).
while IFS= read -r v; do unset "$v"; done < <(env | sed -n 's/^\(NIX_[A-Za-z0-9_]*\)=.*/\1/p')
unset CC CXX LD AR NM RANLIB OBJCOPY OBJDUMP STRIP CPP CXXCPP \
  SDKROOT MACOSX_DEPLOYMENT_TARGET \
  LD_DYLD_PATH LIBRARY_PATH DYLD_LIBRARY_PATH CPATH C_INCLUDE_PATH CPLUS_INCLUDE_PATH

export DEVELOPER_DIR="${DEVELOPER_DIR_OVERRIDE:-/Applications/Xcode.app/Contents/Developer}"
export PATH="${PATH}:/usr/bin:/bin:/usr/sbin:/sbin"

exec flutter "$@"
