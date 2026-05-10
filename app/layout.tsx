import type { Metadata } from "next";
import "../styles/globals.css";

export const metadata: Metadata = {
  title: "Math to Music Visualizer",
  description: "Formula-driven epicycle and waveform visualizer with Web Audio",
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
