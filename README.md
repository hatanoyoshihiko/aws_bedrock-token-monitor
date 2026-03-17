# Bedrock Token Usage Monitor

Amazon Bedrock のトークン使用量を CloudWatch メトリクスで監視し、閾値を超えた場合に SNS 経由で通知する仕組みです。

## 動作の仕組み

CloudWatch の Metric Math を使い、Bedrock が自動出力する以下2つのメトリクスを合算して監視します。

- `AWS/Bedrock` / `InputTokenCount` — 入力トークン数（`input_tokens`）
- `AWS/Bedrock` / `OutputTokenCount` — 出力トークン数（`output_tokens`）
- これらを合算した値を `total_tokens` として算出します。

この合計値を5分間隔で集計し、2期間連続（= 過去10分間）で閾値を超えた場合に CloudWatch Alarm が ALARM 状態に遷移し、指定した SNS トピックへ通知を送信します。

Bedrock を使用していない時間帯はデータポイントが存在しませんが、`TreatMissingData: notBreaching` の設定により誤報は発生しません。アラームが解消（OK 状態に復帰）した際にも SNS 通知が送信されます。

## パラメーター

| パラメーター          | デフォルト値                       | 説明                          |
| --------------------- | ---------------------------------- | ----------------------------- |
| `SnsTopicArn`       | （必須）                           | 通知先の既存 SNS トピック ARN |
| `TokenThreshold`    | `10000`                          | アラーム発火のトークン数閾値  |
| `EvaluationPeriods` | `2`                              | 評価期間数（2 × 5分 = 10分） |
| `Period`            | `300`                            | 各評価期間の長さ（秒）        |
| `ModelId`           | `jp.anthropic.claude-sonnet-4-6` | 監視対象の Bedrock モデル ID  |

## 前提条件

- AWS CLI がインストール・設定済みであること
- CloudFormation のデプロイ権限があること
- 通知先の SNS トピックが作成済みであること（メールサブスクリプションの承認も含む）

## デプロイ

### 環境変数

| 変数              | デフォルト値              | 説明                      |
| ----------------- | ------------------------- | ------------------------- |
| `SNS_TOPIC_ARN` | （必須）                  | 通知先 SNS トピックの ARN |
| `STACK_NAME`    | `bedrock-token-monitor` | CloudFormation スタック名 |
| `AWS_REGION`    | `ap-northeast-1`        | デプロイ先リージョン      |

### SNS トピック ARN の設定

`deploy.sh` を開き、`SNS_TOPIC_ARN` の行を自分の SNS トピック ARN に書き換えてください。

変更前:

```bash
SNS_TOPIC_ARN="${SNS_TOPIC_ARN:?Set SNS_TOPIC_ARN}"
```

変更後:

```bash
SNS_TOPIC_ARN="${SNS_TOPIC_ARN:-arn:aws:sns:ap-northeast-1:123456789012:your-topic}"
```

> `:-` に変更することで、環境変数が未設定の場合にスクリプト内の値が使われます。環境変数で指定すればそちらが優先されます。

環境変数で指定する場合:

```bash
SNS_TOPIC_ARN=arn:aws:sns:ap-northeast-1:123456789012:your-topic bash deploy.sh
```

### 実行

SNS トピック ARN をスクリプトに記載済みであれば、そのまま実行できます。

```bash
bash deploy.sh
```

パラメーターをカスタマイズする場合は、`deploy.sh` の `--parameter-overrides` に追加するか、直接 `aws cloudformation deploy` を実行してください。

```bash
aws cloudformation deploy \
  --template-file template.yaml \
  --stack-name bedrock-token-monitor \
  --parameter-overrides \
    SnsTopicArn=arn:aws:sns:ap-northeast-1:123456789012:your-topic \
    TokenThreshold=10000 \
    ModelId=jp.anthropic.claude-sonnet-4-6
```

## 全モデル合計で監視する場合

デフォルトでは `ModelId` パラメーターで指定した単一モデルのトークン数を監視します。Bedrock 経由の全モデル合計を監視したい場合は、`template.yaml` の `InputTokenCount` と `OutputTokenCount` の両方から `Dimensions` ブロックを削除してください。この変更により `ModelId` モデル単位ではなくBedrock経由のトークン数合計を監視します。

変更前（モデルごと）:

```yaml
MetricStat:
  Metric:
    Namespace: AWS/Bedrock
    MetricName: InputTokenCount
    Dimensions:
      - Name: ModelId
        Value: !Ref ModelId
```

変更後（全モデル合計）:

```yaml
MetricStat:
  Metric:
    Namespace: AWS/Bedrock
    MetricName: InputTokenCount
```

## ファイル構成

```
.
├── template.yaml   # CloudFormation テンプレート
├── deploy.sh       # デプロイスクリプト
└── README.md
```
