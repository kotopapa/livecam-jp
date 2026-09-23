import React from "react";
import { Audio } from "@remotion/media";
import { Series, staticFile } from "remotion";
import { All, Alert, Count, Daily, DUR, End, Hook, MapScene, Shelter, Travel, Weather } from "./Scenes";

export const PROMO_FRAMES = Object.values(DUR).reduce((a, b) => a + b, 0);

// BGM と効果音は promo_video/audio/make_audio.py で合成（外部音源なし）
export const Promo: React.FC = () => (
  <>
  <Audio src={staticFile("audio/promo.wav")} />
  <Series>
    <Series.Sequence durationInFrames={DUR.hook} name="1 問いかけ"><Hook /></Series.Sequence>
    <Series.Sequence durationInFrames={DUR.count} name="2 2万台"><Count /></Series.Sequence>
    <Series.Sequence durationInFrames={DUR.map} name="3 地図"><MapScene /></Series.Sequence>
    <Series.Sequence durationInFrames={DUR.travel} name="4 旅先"><Travel /></Series.Sequence>
    <Series.Sequence durationInFrames={DUR.weather} name="5 天気"><Weather /></Series.Sequence>
    <Series.Sequence durationInFrames={DUR.alert} name="6 通知"><Alert /></Series.Sequence>
    <Series.Sequence durationInFrames={DUR.shelter} name="7 避難先"><Shelter /></Series.Sequence>
    <Series.Sequence durationInFrames={DUR.daily} name="8 注目と備え"><Daily /></Series.Sequence>
    <Series.Sequence durationInFrames={DUR.all} name="9 ぜんぶ"><All /></Series.Sequence>
    <Series.Sequence durationInFrames={DUR.end} name="10 締め"><End /></Series.Sequence>
  </Series>
  </>
);
