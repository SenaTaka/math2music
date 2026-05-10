import { ImageResponse } from "next/og";

export const alt = "Math2Music waveform and epicycle visualizer";
export const size = {
  width: 1200,
  height: 630,
};
export const contentType = "image/png";

export default function Image() {
  return new ImageResponse(
    (
      <div
        style={{
          width: "100%",
          height: "100%",
          display: "flex",
          flexDirection: "column",
          justifyContent: "center",
          alignItems: "center",
          color: "#ffffff",
          background:
            "radial-gradient(circle at 20% 20%, rgba(99,230,255,0.35), transparent 35%), radial-gradient(circle at 80% 80%, rgba(244,114,255,0.3), transparent 34%), #000000",
        }}
      >
        <div
          style={{
            fontSize: 88,
            fontWeight: 700,
            letterSpacing: 0,
            lineHeight: 1,
          }}
        >
          Math2Music
        </div>
        <div
          style={{
            marginTop: 24,
            fontSize: 36,
            opacity: 0.9,
          }}
        >
          Formula to Waveform to Sound
        </div>
      </div>
    ),
    size,
  );
}
