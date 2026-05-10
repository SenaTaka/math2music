import type { Metadata } from "next";
import "../styles/globals.css";

export const metadata: Metadata = {
  metadataBase: new URL(
    process.env.NEXT_PUBLIC_SITE_URL || "https://math2music.vercel.app",
  ),
  title: "Math2Music | Formula Sound Visualizer",
  description:
    "Turn math formulas into neon epicycles, waveforms, and audio. Record and share your result as short vertical video.",
  openGraph: {
    title: "Math2Music | Formula Sound Visualizer",
    description:
      "Turn math formulas into neon epicycles, waveforms, and audio. Record and share your result as short vertical video.",
    type: "website",
    images: [{ url: "/opengraph-image" }],
  },
  twitter: {
    card: "summary_large_image",
    title: "Math2Music | Formula Sound Visualizer",
    description:
      "Turn math formulas into neon epicycles, waveforms, and audio. Record and share your result as short vertical video.",
    images: ["/opengraph-image"],
  },
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en" className="h-full antialiased">
      <body className="min-h-full flex flex-col">{children}</body>
    </html>
  );
}
