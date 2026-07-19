## 2026/07/18 (リリース準備)
- ios/project.yml: bundle id を com.senatakasawa.math2music に変更、DEVELOPMENT_TEAM 6325NASDSP を設定
- xcodegen generate → Simulator ビルド成功 + 実機向けアーカイブ(署名込み)成功
- homepage リポジトリに apps/math2music/(サポート+プラポリページ)を追加しコミット f21e10d(デプロイは権限ブロックで未実施 → ユーザー実行待ち)
- docs/APP_STORE.md チェックリスト更新、README のビルド手順を実状に合わせ修正
- 残: homepage デプロイ / ASC アプリ作成+メタデータ+スクショ / 実機最終確認 / アップロード(提出はユーザー)
## 2026/07/19 (TestFlight/Xcode Cloud 準備)
- ASC に bundle ID com.senatakasawa.math2music を API で登録(ID: S69SCP5AYD)
- Xcode Cloud 対応: ios/ci_scripts/ci_post_clone.sh(xcodegen 生成)+ ios/Package.resolved を追跡(SPM 解決失敗の既知事象対策)
- 残(人間作業): ASC でアプリレコード作成 → Xcode で Xcode Cloud ワークフロー作成(GitHub 連携)→ TestFlight 内部配信 → 審査提出はユーザー
## 2026/07/19 (UX/音質改善 — builder委任)
- 数式ラベル拡大(.footnote→.title3)、全スライダーに数値表示(BPM/VOL%/Hz)
- 音質: サチュレータ k=280 の常時飽和が不快音の根本原因 → tanh(x*1.1) へ刷新、ハイシェルフ+7.5→+5dB、ローパスQ 5.4→2.0dB
- 基底波形セレクタ追加(sin/cos/tri/saw/square)— DSP・描画・書き出し3系統一致、お気に入り後方互換
- HIG: セマンティックフォント化、主要ボタン44pt、VoiceOver対応。SEで非スクロール維持
- 音の主観評価(実機リスニング)は未実施 → ユーザー確認待ち
