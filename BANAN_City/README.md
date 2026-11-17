# BANAN_City 手伝い用ワークスペース
- server-copy/ : FTPからダウンロードした友人サーバーのコピー(直接編集しない)
- my-changes/  : 自分が作る/修正するリソースをここで作業し、確認後にFTPへアップロード
  - `my-changes/[Kani-script]/<リソース>` がコードの正本(サーバーの `[Kani-script]` と同じ形。ここ以外にコピーを持たない)
  - 導入手順・友人に頼むことは `my-changes/導入メモ_<リソース>.md`(アップロードしない)。アイテム画像などもその横に置く
- assets/      : Blender などの元データ・変換スクリプト(サーバーには上げない)

## 作業ルール
1. アップロード前に必ず友人のファイルのバックアップ(ダウンロード)を取る
2. 1リソースずつ変更し、友人に伝えてから反映
3. FTP情報はWinSCPにだけ保存。チャット・ファイルに書かない

## 編集許可範囲（厳守）
サーバー上で編集してよいのは次のフォルダ配下のみ:
`/opt/fivem/fivem_server/txData/Qbox_5515B3.base/resources/[Kani-script]`
それ以外（他のresources、server.cfg、txData等）は変更しない。参照（読み取り）は自由。
フレームワーク: Qbox
