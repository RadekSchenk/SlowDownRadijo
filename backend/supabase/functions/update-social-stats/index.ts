// Runs on a schedule (see backend/README.md's Cron section) to refresh
// follower/like counts for the station's social links (Menu ▸ social row —
// see SlowDownRadijo/Views/Hub/SocialLinksRow.swift), cached in
// `social_stats` rather than fetched live per app-open.
//
// None of these platforms have a simple, free, unauthenticated public API
// for follower counts (YouTube's official Data API v3 is the one
// exception). Instagram, Threads, and Facebook profile pages still embed
// the count in their `og:description` meta tag for plain (non-JS) HTTP
// requests, PROVIDED the request looks like something the platform is
// willing to serve statically:
//  - Instagram/Threads: a normal mobile Safari User-Agent works fine.
//  - Facebook: a plain browser UA gets redirected to a JS-only shell (no
//    data) — a Googlebot User-Agent gets the real server-rendered page
//    instead, since Facebook explicitly allows search-engine crawling of
//    public pages for SEO.
// This is inherently fragile (any of the three could change their HTML or
// tighten anti-bot rules at any time) — if a platform starts returning
// null here, check its og:description tag manually first before assuming
// the whole approach is dead.

import { createClient } from "npm:@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
// Optional — YouTube is skipped gracefully (not a hard failure) if unset.
// Create one at https://console.cloud.google.com/apis/credentials (enable
// "YouTube Data API v3" first), then `supabase secrets set YOUTUBE_API_KEY=...`.
const YOUTUBE_API_KEY = Deno.env.get("YOUTUBE_API_KEY");

const MOBILE_SAFARI_UA =
  "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko)";
const GOOGLEBOT_UA = "Mozilla/5.0 (compatible; Googlebot/2.1; +http://www.google.com/bot.html)";

/// Extracts the leading number from an `og:description` meta tag's content
/// (e.g. `"1,279 Followers, 409 Following..."` -> 1279, or the Czech
/// `"757 To se mi líbí ..."` -> 757). Strips both `,` and `.` as thousands
/// separators rather than trying to parse locale-specific number formats —
/// these are always whole follower/like counts, never fractional.
function leadingCount(html: string): number | null {
  const match = html.match(/og:description"\s+content="([\d,.]+)\s/);
  if (!match) return null;
  const digits = match[1].replace(/[.,]/g, "");
  const parsed = parseInt(digits, 10);
  return Number.isFinite(parsed) ? parsed : null;
}

async function fetchInstagramFollowers(): Promise<number | null> {
  const res = await fetch("https://www.instagram.com/slowdownradijocz/", {
    headers: { "User-Agent": MOBILE_SAFARI_UA, "Accept-Language": "en-US,en;q=0.9" },
  });
  if (!res.ok) return null;
  return leadingCount(await res.text());
}

async function fetchThreadsFollowers(): Promise<number | null> {
  const res = await fetch("https://www.threads.com/@slowdownradijocz", {
    headers: { "User-Agent": MOBILE_SAFARI_UA, "Accept-Language": "en-US,en;q=0.9" },
  });
  if (!res.ok) return null;
  return leadingCount(await res.text());
}

async function fetchFacebookFollowers(): Promise<number | null> {
  const res = await fetch("https://www.facebook.com/slowdownradijo/", {
    headers: { "User-Agent": GOOGLEBOT_UA },
  });
  if (!res.ok) return null;
  return leadingCount(await res.text());
}

async function fetchYouTubeSubscribers(): Promise<number | null> {
  if (!YOUTUBE_API_KEY) return null;
  const url = `https://www.googleapis.com/youtube/v3/channels?part=statistics&forHandle=slowdownradijo&key=${YOUTUBE_API_KEY}`;
  const res = await fetch(url);
  if (!res.ok) return null;
  const json = await res.json();
  const count = json?.items?.[0]?.statistics?.subscriberCount;
  return count ? parseInt(count, 10) : null;
}

Deno.serve(async (_req) => {
  const supabase = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);

  const platforms: Array<{ platform: string; fetcher: () => Promise<number | null> }> = [
    { platform: "instagram", fetcher: fetchInstagramFollowers },
    { platform: "threads", fetcher: fetchThreadsFollowers },
    { platform: "facebook", fetcher: fetchFacebookFollowers },
    { platform: "youtube", fetcher: fetchYouTubeSubscribers },
  ];

  const results = await Promise.allSettled(
    platforms.map(async ({ platform, fetcher }) => ({ platform, count: await fetcher() }))
  );

  const rows: { platform: string; follower_count: number; updated_at: string }[] = [];
  const skipped: string[] = [];
  const updatedAt = new Date().toISOString();

  results.forEach((result, index) => {
    const platform = platforms[index].platform;
    if (result.status === "fulfilled" && result.value.count !== null) {
      rows.push({ platform, follower_count: result.value.count, updated_at: updatedAt });
    } else {
      skipped.push(platform);
      if (result.status === "rejected") {
        console.error(`${platform} fetch failed:`, result.reason);
      } else {
        console.warn(`${platform} count not found in response`);
      }
    }
  });

  if (rows.length === 0) {
    return new Response(JSON.stringify({ error: "No platforms fetched successfully", skipped }), { status: 502 });
  }

  const { error } = await supabase.from("social_stats").upsert(rows, { onConflict: "platform" });
  if (error) {
    console.error("Upsert error:", error);
    return new Response(JSON.stringify({ error: error.message }), { status: 500 });
  }

  return new Response(JSON.stringify({ updated: rows, skipped }), { status: 200 });
});
