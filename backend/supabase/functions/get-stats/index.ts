// Public read-only endpoint the app calls for the "Statistiky" tab —
// combines the SQL stats functions (see backend/supabase/sql/*.sql) into
// one JSON response.

import { createClient } from "npm:@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
// Anon key is enough — these are SELECT-only stable functions guarded by
// the same RLS "Allow public read" policy as the table itself.
const ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY")!;

Deno.serve(async (_req) => {
  const supabase = createClient(SUPABASE_URL, ANON_KEY);

  const [diversity, repetition, firstPlaysCount, firstPlaysSample, totalUniqueTracks] = await Promise.all([
    supabase.rpc("diversity_weekly", { weeks_back: 12 }),
    supabase.rpc("repetition_rate", { days_back: 30 }),
    supabase.rpc("first_plays_week_count"),
    supabase.rpc("first_plays_week_sample", { limit_count: 5 }),
    supabase.rpc("total_unique_tracks_count"),
  ]);

  if (
    diversity.error || repetition.error || firstPlaysCount.error ||
    firstPlaysSample.error || totalUniqueTracks.error
  ) {
    console.error(
      "Stats query error:",
      diversity.error,
      repetition.error,
      firstPlaysCount.error,
      firstPlaysSample.error,
      totalUniqueTracks.error
    );
    return new Response(JSON.stringify({ error: "Failed to compute stats" }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }

  return new Response(
    JSON.stringify({
      diversityWeekly: diversity.data,
      repetition: repetition.data?.[0] ?? null,
      firstPlaysWeekCount: firstPlaysCount.data,
      firstPlaysSample: firstPlaysSample.data,
      totalUniqueTracks: totalUniqueTracks.data,
    }),
    { status: 200, headers: { "Content-Type": "application/json" } }
  );
});
