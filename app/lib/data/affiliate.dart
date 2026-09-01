/// アフィリエイト（バリューコマース）リンクの組み立て。
///
/// 収益導線はこのファイルに閉じ込める。画面側は [AffiliateLinks] だけを使い、
/// SID/PID・エンドポイントの知識を持たない。広告主の定義（pid・有効/無効・
/// 検索URL）は `config.dart` の [vcMerchants] にある。
///
/// 規約上の注意（実装で守っていること）:
/// - 生成したURLは **必ず外部ブラウザ**（`LaunchMode.externalApplication`）で開く。
///   アプリ内WebViewはCookieが分離されて成果が計測されないうえ、
///   広告主によっては規約違反になる。
/// - 商品リンクを置く画面には「アフィリエイトプログラムを利用しています」の
///   明示を必ず併記する（景品表示法のステルスマーケティング規制・
///   令和5年10月1日施行）。文言は ARB の `stockpileAffiliateNotice`。
/// - 提携が**承認されていない広告主は出さない**（[vcMerchants] の
///   `enabled: false`）。承認されたら true にするだけで画面に増える。
/// - 1×1のインプレッション用画像（ad.jp.ap.valuecommerce.com/servlet/gifbanner）
///   はWebサイト用なのでアプリでは使わない。計測は referral リンクで行われる。
library;

import '../config.dart';

class AffiliateLinks {
  const AffiliateLinks._();

  /// 有効な広告主だけを取り出す（テストのため一覧を差し替えられるようにする）
  static List<VcMerchant> enabledIn(List<VcMerchant> merchants) =>
      [for (final m in merchants) if (m.enabled && m.pid.isNotEmpty) m];

  /// いま画面に出してよい広告主（提携承認済みのものだけ）
  static List<VcMerchant> get enabledMerchants => enabledIn(vcMerchants);

  /// 導線が使えるか（sid未設定・全店舗未承認なら false → ボタンを出さない）
  static bool get isAvailable => vcSid.isNotEmpty && enabledMerchants.isNotEmpty;

  /// 有効な広告主が2つ以上あるか（true なら「探す」で店舗選択シートを出す）
  static bool needsPickerIn(List<VcMerchant> merchants) =>
      enabledIn(merchants).length > 1;

  static bool get needsMerchantPicker => needsPickerIn(vcMerchants);

  /// キーから広告主を引く（未定義・無効なら null）
  static VcMerchant? merchantOf(String key) =>
      enabledMerchants.where((m) => m.key == key).firstOrNull;

  /// バリューコマースのリファラルURLを組み立てる。
  ///
  /// `vc_url` は遷移先URL全体を**パーセントエンコード**して渡す
  /// （`?` `&` `=` `:` `/` もエンコードする必要があるため
  /// `Uri.encodeComponent` を使い、クエリは文字列で組み立てる）。
  static Uri referral({
    required String sid,
    required String pid,
    required Uri destination,
  }) =>
      Uri.parse('$vcReferralEndpoint?sid=$sid&pid=$pid'
          '&vc_url=${Uri.encodeComponent(destination.toString())}');

  /// 検索語 [keyword] を [merchant] で検索するアフィリエイトリンク。
  /// 未承認の広告主・空の検索語では null を返す。
  static Uri? searchLink(String keyword, VcMerchant merchant) {
    final k = keyword.trim();
    if (k.isEmpty || vcSid.isEmpty) return null;
    if (!merchant.enabled || merchant.pid.isEmpty) return null;
    return referral(
      sid: vcSid,
      pid: merchant.pid,
      destination: merchant.searchUrl(k),
    );
  }

  /// 有効な広告主が1つだけのときの遷移先（複数あるときは null →
  /// 画面側が店舗選択シートを出す）。
  static Uri? soleSearchLinkIn(String keyword, List<VcMerchant> merchants) {
    final ms = enabledIn(merchants);
    if (ms.length != 1) return null;
    return searchLink(keyword, ms.first);
  }

  static Uri? soleSearchLink(String keyword) =>
      soleSearchLinkIn(keyword, vcMerchants);
}
