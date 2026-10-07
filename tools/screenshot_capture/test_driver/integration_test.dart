// ストア用スクリーンショット撮影の driver（ホスト側）。
// 撮影そのものは run_capture.sh が「SNAP <名前>」行を見て simctl で行うので、
// ここは integration_test の結果を受け取るだけ。
import 'package:integration_test/integration_test_driver.dart';

Future<void> main() => integrationDriver();
