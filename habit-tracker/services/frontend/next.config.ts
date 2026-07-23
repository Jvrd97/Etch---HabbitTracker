// [review:need-review] PHASE-01/30-lan-api-proxy-rewrite
// summary: proxy /api/v1 to the backend so the app works from any LAN device
import type { NextConfig } from "next";

// Server-side only: where the Next server forwards /api/v1 requests.
// Not NEXT_PUBLIC_* on purpose — the browser must never see this host.
const API_PROXY_TARGET = process.env.API_PROXY_TARGET || 'http://localhost:8000';

const nextConfig: NextConfig = {
  /* config options here */
  reactCompiler: true,
  // Dev-only: extra hosts allowed to load /_next/* (e.g. a phone on the LAN).
  // Comma-separated list in DEV_ORIGINS, empty by default.
  allowedDevOrigins: process.env.DEV_ORIGINS?.split(',') ?? [],
  async rewrites() {
    return [
      {
        source: '/api/v1/:path*',
        destination: `${API_PROXY_TARGET}/api/v1/:path*`,
      },
    ];
  },
};

export default nextConfig;
