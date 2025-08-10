===========================================
README - app_Lab_Note_Generator.R（Shinyアプリ）
バージョン: 1.0.0
作成者: Shuichi Sugiura
作成日: 2025-08-09
コードネーム: Wadden
===========================================

■ 概要

この Shiny アプリは，心理学実験における実験記録（ラボノート）を自動生成するツールです。
被験者IDを入力すると，事前に用意されたランダム化リスト（`randomization_list.csv`）に基づき，
Heartbeat Counting Task（HCT）の試行順序を自動で割り当てます。

入力された実験情報（被験者ID，実験室番号，実験者名，開始時刻，終了時刻）をもとに、
以下の形式で保存します。

- PDF または 編集可能な Rmd のラボノート
- UTF-8 BOM 形式の CSV（Windows/Mac の Excel で文字化けなし）

---

■ 特徴

- 被験者IDを入力するだけで HCT 試行順序を自動表示
- 実験の開始時刻・終了時刻を現在時刻ボタンで即入力可能
- 実験室番号や実験者名をフォームから入力
- ラボノートを PDF または Rmd 形式で出力
- CSV は UTF-8 BOM 形式で保存し、Windows/Mac Excel 双方で文字化け防止
- 被験者IDは自動的に3桁表示（例：001）

---

■ 使用方法

1. R または RStudio で `app_Lab_Note_Generator.R` を開きます。

2. 以下のコマンドでアプリを起動します：

shiny::runApp("app_Lab_Note_Generator.R")

3. GUIが起動したら、以下の項目を入力します：

- 実験室番号（例：A-101）
- 実験者名（例：杉浦　秀一）
- 被験者ID（例：1 → 自動で001に変換）
- 実験開始時間（または「現在」ボタン）
- 実験終了時間（または「現在」ボタン）

4. 「レポート生成」ボタンを押すと、以下が保存されます：
- `ID-001-labnote.pdf`（または `.Rmd`）
- `ID-001-labnote.csv`

---

■ 出力例（CSV）

```
ID,ExperimentOrder,HCT_Order,StartTime,EndTime,LabNumber,Experimenter,Date
001,Heart rate Counting Task → Experiment → Questionnaire,"30秒 → 45秒 → 55秒",2025-08-09 14:00,2025-08-09 14:30,Lab-1,杉浦 秀一,2025-08-09
```

---

■ ファイル構成

- `app_Lab_Note_Generator.R` : アプリ本体（日本語版）
- `labnote_template.Rmd` : PDF/Rmd 出力用テンプレート（日本語版）
- `randomization_list.csv` : HCT試行順序のサンプルリスト
- `ReadME.txt` : 日本語説明ファイル

---

■ 注意事項

- `randomization_list.csv` はサンプルです。実験計画に合わせて適宜作成してください。
- 被験者IDは半角数字で入力してください（例：1 → 自動で001に変換）。
- CSV 出力は UTF-8 BOM 形式です。Windows/Mac 両方で文字化けしません。
- 本アプリはすべてローカルで動作します。生成されたデータはオンラインに送信されません。

---

■ 開発情報

- バージョン　　: 1.0.0
- コードネーム　: Wadden
- 最終更新日　　: 2025-08-09
- 制作者　　　　: Shuichi Sugiura

---

■ Special Thanks

このプログラムは，オランダにある WEC (World Heritage Centre Wadden Sea) のアザラシのライブ配信を見ながら開発しました。
研究者や開発者の方でストレスを感じている方がいれば，ぜひ一度，WECのライブ映像をご覧ください。心が穏やかになるかもしれません。
WECの活動に深い敬意と感謝を込めて。
※本プログラムは WEC とは一切関係がありません。

