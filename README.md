# Zoho Creator × Gemini AI ハッカソン

## 業務アイデアを、AIと一緒にZoho Creatorアプリへ

このRepositoryは、Zoho CreatorとGoogle Geminiを組み合わせて、
参加者自身の業務アイデアから業務アプリを作成するためのハッカソン用教材・ツール一式を提供します。

プログラミングやZoho Creatorの専門知識がなくても、
Geminiの「Gem」を使いながら、

> 業務アイデア
> ↓
> アプリ設計
> ↓
> Zoho Creatorアプリ生成
> ↓
> 機能追加
> ↓
> 業務で使えるアプリへ

という流れを体験できます。


---

# 1. まず最初にやること

参加者は、以下の順番で進めてください。

### STEP 1
`01_参加者手順書` にある参加者向け手順書を開きます。

### STEP 2
`02_Gemプロンプト` にあるGem①・Gem②の指示文を使って、
Google Geminiに2つのGemを作成します。

### STEP 3
指定されたナレッジファイルをGemに登録します。

### STEP 4
自分が改善したい業務をGem①に伝えます。

### STEP 5
Gem①と対話しながらアプリの仕様を決めます。

### STEP 6
仕様を確認して「OK」とした後、Gem①にZoho Creator用のDSを生成させます。

### STEP 7
生成されたDSをZoho Creatorへインポートします。

### STEP 8
Zoho Creatorでアプリを動かして確認します。

### STEP 9
Zoho Creatorから最新のDSをエクスポートし、Gem②へ渡します。

### STEP 10
Gem②を使ってワークフローやレポートなどの機能を追加します。

### STEP 11
完成したアプリを確認します。


---

# 2. 全体の流れ

```text
自分の業務アイデア
        ↓
      Gem①
        ↓
   アプリ仕様書
        ↓
  人間が確認・修正
        ↓
       「OK」
        ↓
      DS生成
        ↓
   Zoho Creator
        ↓
    動作確認
        ↓
 最新DSをエクスポート
        ↓
      Gem②
        ↓
ワークフロー・レポート追加
        ↓
   Zoho Creator
        ↓
      完成
