// Runs on a schedule (see backend/README.md's Cron section) to poll the
// live ICY stream metadata and log track changes to `played_tracks` —
// independent of whether the app is open. Mirrors the exact parsing logic
// in SlowDownRadijo/Services/ICYMetadataService.swift and
// SlowDownRadijo/Models/NowPlayingTrack.swift.
//
// Deliberately reads the Icecast stream directly, NOT slowdownradijo.cz's
// own "co hrálo" API — that data was found to be months stale (see
// backend/README.md / project history), which is exactly why the app
// stopped relying on it in the first place.

import { createClient } from "npm:@supabase/supabase-js@2";
// A copy of SlowDownRadijo/Resources/schedule.json — Edge Functions can only
// bundle files within their own directory, so this has to be duplicated
// rather than shared. If the iOS app's schedule.json changes, re-copy it
// here and redeploy (`supabase functions deploy collect-now-playing`).
import scheduleData from "./schedule.json" with { type: "json" };

const STREAM_URL = "https://icecast5.play.cz/slowdown.aac";
// Auto-provided to every Edge Function by the Supabase platform — not a
// secret we set ourselves.
const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

interface ScheduleShow {
  name: string;
  start: string;
  end: string;
}

interface ScheduleDay {
  weekday: number; // 1 = Sunday ... 7 = Saturday, matching Calendar.weekday
  shows: ScheduleShow[];
}

const scheduleDays = (scheduleData as { days: ScheduleDay[] }).days;

function minutesFromMidnight(hhmm: string): number | null {
  const [hourStr, minuteStr] = hhmm.split(":");
  const hour = parseInt(hourStr, 10);
  const minute = parseInt(minuteStr, 10);
  if (Number.isNaN(hour) || Number.isNaN(minute)) return null;
  return hour * 60 + minute;
}

const WEEKDAY_BY_SHORT_NAME: Record<string, number> = {
  Sun: 1, Mon: 2, Tue: 3, Wed: 4, Thu: 5, Fri: 6, Sat: 7,
};

/// Resolves which show was airing at `date`, based on Europe/Prague local
/// time (the station's own timezone) — mirrors
/// `ScheduleStore.currentShow(at:)` in the iOS app. Returns `null` if the
/// schedule doesn't cover that slot.
function findCurrentShowName(date: Date): string | null {
  const parts = new Intl.DateTimeFormat("en-US", {
    timeZone: "Europe/Prague",
    weekday: "short",
    hour: "2-digit",
    minute: "2-digit",
    hourCycle: "h23",
  }).formatToParts(date);

  const weekdayShort = parts.find((p) => p.type === "weekday")?.value;
  const hour = parseInt(parts.find((p) => p.type === "hour")?.value ?? "", 10);
  const minute = parseInt(parts.find((p) => p.type === "minute")?.value ?? "", 10);
  if (!weekdayShort || Number.isNaN(hour) || Number.isNaN(minute)) return null;

  const weekday = WEEKDAY_BY_SHORT_NAME[weekdayShort];
  const day = scheduleDays.find((d) => d.weekday === weekday);
  if (!day) return null;

  const minutesOfDay = hour * 60 + minute;
  for (const show of day.shows) {
    const start = minutesFromMidnight(show.start);
    const rawEnd = minutesFromMidnight(show.end);
    if (start === null || rawEnd === null) continue;
    const end = rawEnd === 0 ? 1440 : rawEnd; // "00:00" end means midnight/end of day
    if (minutesOfDay >= start && minutesOfDay < end) return show.name;
  }
  return null;
}

interface ParsedTrack {
  artist: string;
  title: string;
}

function parseStreamTitle(raw: string): ParsedTrack | null {
  const trimmed = raw.trim();
  if (!trimmed) return null;

  let parts = trimmed.split(" - ").map((p) => p.trim());

  // The station prefixes the station name ("SLOWDOWN") on every title; drop it.
  if (parts.length > 2 && parts[0].toUpperCase() === "SLOWDOWN") {
    parts = parts.slice(1);
  }

  if (parts.length >= 2) {
    return { artist: parts[0], title: parts.slice(1).join(" - ") };
  }
  return { artist: "", title: parts[0] };
}

/// Connects just long enough to read one ICY metadata block, then closes
/// the connection — same bounded-single-read approach as
/// `ICYMetadataService.pollOnce`, not a persistent listener.
async function fetchCurrentTrack(): Promise<ParsedTrack | null> {
  const response = await fetch(STREAM_URL, {
    headers: {
      "Icy-MetaData": "1",
      // The station's WAF has previously blocked requests without a
      // realistic browser User-Agent.
      "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko)",
    },
  });

  const metaIntHeader = response.headers.get("icy-metaint");
  const metaInt = metaIntHeader ? parseInt(metaIntHeader, 10) : 0;
  if (!metaInt || !response.body) {
    await response.body?.cancel();
    return null;
  }

  const reader = response.body.getReader();
  let buffered = new Uint8Array(0);

  function append(chunk: Uint8Array) {
    const combined = new Uint8Array(buffered.length + chunk.length);
    combined.set(buffered);
    combined.set(chunk, buffered.length);
    buffered = combined;
  }

  try {
    // Skip metaInt bytes of audio, then read the 1-byte length.
    let need = metaInt + 1;
    while (buffered.length < need) {
      const { value, done } = await reader.read();
      if (done) return null;
      append(value);
    }

    const lengthByte = buffered[metaInt];
    const metaLength = lengthByte * 16;
    if (metaLength === 0) return null; // server signalled "no change" this cycle

    need = metaInt + 1 + metaLength;
    while (buffered.length < need) {
      const { value, done } = await reader.read();
      if (done) return null;
      append(value);
    }

    const metaBytes = buffered.slice(metaInt + 1, metaInt + 1 + metaLength);
    const raw = new TextDecoder("utf-8").decode(metaBytes);
    const match = raw.match(/StreamTitle='(.*?)';/s);
    if (!match) return null;

    return parseStreamTitle(match[1]);
  } finally {
    await reader.cancel().catch(() => {});
  }
}

Deno.serve(async (_req) => {
  const supabase = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);

  let track: ParsedTrack | null;
  try {
    track = await fetchCurrentTrack();
  } catch (error) {
    console.error("Stream fetch failed:", error);
    return new Response(JSON.stringify({ error: "Stream fetch failed" }), { status: 502 });
  }

  if (!track || !track.artist || !track.title) {
    return new Response(JSON.stringify({ skipped: "no track parsed" }), { status: 200 });
  }

  const { data: last } = await supabase
    .from("played_tracks")
    .select("artist, title")
    .order("played_at", { ascending: false })
    .limit(1)
    .maybeSingle();

  if (last && last.artist === track.artist && last.title === track.title) {
    return new Response(JSON.stringify({ skipped: "unchanged" }), { status: 200 });
  }

  const playedAt = new Date();
  const showName = findCurrentShowName(playedAt);

  const { error } = await supabase.from("played_tracks").insert({
    artist: track.artist,
    title: track.title,
    played_at: playedAt.toISOString(),
    show_name: showName,
  });

  if (error) {
    console.error("Insert error:", error);
    return new Response(JSON.stringify({ error: error.message }), { status: 500 });
  }

  return new Response(JSON.stringify({ inserted: { ...track, showName } }), { status: 200 });
});
