import "./index.css";
import { Composition } from "remotion";
import { Promo, PROMO_FRAMES } from "./promo/Promo";

// 全国ライブカメラ地図 30秒プロモーション（縦 1080×1920・30fps）
export const RemotionRoot: React.FC = () => (
  <Composition id="Promo" component={Promo} durationInFrames={PROMO_FRAMES} fps={30} width={1080} height={1920} />
);
