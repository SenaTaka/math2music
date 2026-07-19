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
## 2026/07/19 (ASC 反映 — 提出可能状態まで)
- API 反映: 名前/サブタイトル/プラポリURL/カテゴリ(MUSIC/ENT)/年齢4+/説明/キーワード/プロモ/著作権/審査連絡先/価格¥600(JPN)/配信175地域
- ビルド 1.0(1) を altool で直接アップロード(キーは ~/.private_keys に symlink 要)→ VALID → バージョンに紐付け
- スクショ: builder が XCUITest 駆動で ja/en 各5枚撮影(1290×2796)→ store_frame 加工 → asc_upload_screenshots.py で ASC 反映
- store/ 一式 + UITest ターゲットをコミット。残る人間作業: App Privacy(データ収集なし)設定と提出ボタンのみ
## 2026/07/20 (ストア文言の AI 感除去+ASO 見直し)
- ユーザー指摘「完璧ループ等が AI っぽい」→ ja/en の説明文・プロモ文・キーワードを書き直し(規律は store/ASO_NOTES.md 2026-07-20 参照)
- スクショ 04(ja/en)を store_frame.swift で新キャプションに再合成(「つなぎ目のないループ動画を4Kで」/ "Seamless loops, exported in 4K")
- store_lint PASS 後、asc_update_metadata.py + asc_upload_screenshots.py で ASC 反映(提出はしていない)
- 競合ページ実査(Vibely/Fourier Series Visualiser)→ 機能改善アイデア 5 件を docs/APP_STORE.md に記録(筆頭: 9:16 縦動画書き出し = Spotify Canvas/Reels 用途)
## 2026/07/20 (書き出し高速化 — 指揮官直営)
- LoopVideoExporter: フレーム描画を有界並列化(TaskGroup、同時=コア数、append は順序維持)。出力は決定的に同一
- SceneRenderer のグロー安価化(レイヤーストローク近似)は3案計測の結果すべて見送り→シャドウ実装に完全復帰(3層=バンディング/8層丸ジョイン=4K 283s と逆効果)
- 計測(シミュレータ Release, 6s): before 直列 1080p 15.7s/4K 84s、並列のみ 1080p 15.3s/4K 110s、エンコード単体プローブ 4K 31.6s → シミュレータはソフトウェア H.264 が CPU を食い、並列描画と競合して逆効果に見える(実機は HW エンコードで競合なし)
- ExportBenchmark.swift(EXPORT_BENCH=1 / EXPORT_BENCH_APPEND=1)を恒久ハーネスとして追加
- 実機計測は iPhone 未接続(ロック中)で未実施 → 実機で要確認
