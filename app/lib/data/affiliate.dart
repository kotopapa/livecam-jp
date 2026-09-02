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
import 'stockpile_products.dart' show ProductRef;

class AffiliateLinks {
  const AffiliateLinks._();

  /// 配信JSON（stockpile/products.json の `merchants`）から受け取った有効フラグ。
  /// config.dart の `enabled` を上書きする。承認された広告主をアプリ更新なしで
  /// 有効化するため（1.4.0）。未取得のうちは空＝config の既定値
  static Map<String, bool> remoteFlags = const {};

  static void applyRemoteFlags(Map<String, bool> flags) {
    remoteFlags = Map.unmodifiable(flags);
  }

  /// 配信フラグを反映した広告主一覧（pid の無い店舗は有効化されても出ない）
  static List<VcMerchant> get merchants => [
    for (final m in vcMerchants)
      remoteFlags.containsKey(m.key)
          ? VcMerchant(
              key: m.key,
              name: m.name,
              pid: m.pid,
              enabled: remoteFlags[m.key]!,
              searchUrl: m.searchUrl,
            )
          : m,
  ];

  /// 有効な広告主だけを取り出す（テストのため一覧を差し替えられるようにする）
  static List<VcMerchant> enabledIn(List<VcMerchant> merchants) => [
    for (final m in merchants)
      if (m.enabled && m.pid.isNotEmpty) m,
  ];

  /// いま画面に出してよい広告主（提携承認済みのものだけ）
  static List<VcMerchant> get enabledMerchants => enabledIn(merchants);

  /// 導線が使えるか（sid未設定・全店舗未承認なら false → ボタンを出さない）
  static bool get isAvailable =>
      vcSid.isNotEmpty && enabledMerchants.isNotEmpty;

  /// 有効な広告主が2つ以上あるか（true なら「探す」で店舗選択シートを出す）
  static bool needsPickerIn(List<VcMerchant> merchants) =>
      enabledIn(merchants).length > 1;

  static bool get needsMerchantPicker => needsPickerIn(merchants);

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
  }) => Uri.parse(
    '$vcReferralEndpoint?sid=$sid&pid=$pid'
    '&vc_url=${Uri.encodeComponent(destination.toString())}',
  );

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
      soleSearchLinkIn(keyword, merchants);

  /// 定番商品 [product] を [merchant] で開くアフィリエイトリンク。
  ///
  /// - `shop` が店舗キーと一致する（モール上の商品ページ）ならその商品ページを
  ///   リファラルで包む
  /// - それ以外（メーカー公式ページなど）は商品名で店舗を検索する。
  ///   公式ページをリファラルで包んでも成果にならないため
  static Uri? productLink(ProductRef product, VcMerchant merchant) {
    if (!merchant.enabled || merchant.pid.isEmpty || vcSid.isEmpty) return null;
    if (product.shop == merchant.key) {
      final dest = Uri.tryParse(product.url);
      if (dest == null) return null;
      return referral(sid: vcSid, pid: merchant.pid, destination: dest);
    }
    return searchLink(product.searchKeyword, merchant);
  }

  /// [product] に出す店舗。モール商品ページならその店舗だけ、公式ページなら全提携先
  static List<VcMerchant> productMerchantsIn(
    ProductRef product,
    List<VcMerchant> merchants,
  ) {
    final enabled = enabledIn(merchants);
    final own = enabled.where((m) => m.key == product.shop).toList();
    return own.isNotEmpty ? own : enabled;
  }

  static List<VcMerchant> productMerchants(ProductRef product) =>
      productMerchantsIn(product, merchants);
}
