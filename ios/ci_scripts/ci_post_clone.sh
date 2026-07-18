#!/bin/sh
# Xcode Cloud: クローン直後に実行される。
# .xcodeproj は XcodeGen 生成物で git 未追跡のため、ここで生成する。
# Package.resolved は Xcode Cloud の SPM 解決に必須(無いとビルド失敗する既知事象)
# なので、リポジトリ追跡の ios/Package.resolved を生成プロジェクトへ配置する。
set -e

brew install xcodegen

cd "$CI_PRIMARY_REPOSITORY_PATH/ios"
xcodegen generate

RESOLVED_DIR="Math2Music.xcodeproj/project.xcworkspace/xcshareddata/swiftpm"
mkdir -p "$RESOLVED_DIR"
cp Package.resolved "$RESOLVED_DIR/Package.resolved"
