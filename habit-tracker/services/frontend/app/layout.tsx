// [review:need-review] PHASE-01/adhoc-lime-redesign
// summary: Root layout with Inter font and dark Lime Tech shell background
import type { Metadata } from "next";
import { Inter } from "next/font/google";
import "./globals.css";
import Navigation from "@/components/Navigation";

const inter = Inter({ subsets: ["latin"] });

export const metadata: Metadata = {
  title: "Habit Tracker - Track Your Life",
  description: "A powerful habit tracking application with dynamic categories and fields",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en">
      <body className={`${inter.className} bg-background text-text-primary min-h-screen antialiased`}>
        <Navigation />
        <main className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-10">
          {children}
        </main>
      </body>
    </html>
  );
}
