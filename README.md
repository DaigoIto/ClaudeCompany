# ClaudeCompany

どんな事業でも使える汎用CEOシステム。オンボーディング3問で即運用開始。サブAgentは稟議で追加。

Claude Code のプラグインとして動作します。`/company` スラッシュコマンドから、CEO Agentがオンボーディングを経て組織運営を開始します。

## チームメンバーのインストール方法

Claude Code 上で以下を実行してください。

```
/plugin marketplace add DaigoIto/ClaudeCompany
/plugin install company@ClaudeCompany
```

インストール後、任意のプロジェクトディレクトリで `/company` を実行するとオンボーディングが始まります。

## アップデート

```
/plugin marketplace update ClaudeCompany
```

## 構成

```
plugins/company/
├── .claude-plugin/plugin.json   # プラグイン定義
└── skills/company/
    ├── SKILL.md                 # メインスキル定義
    └── references/              # CLAUDE.md・部署・リード管理などのテンプレート
```
