// Shared limiter for the public e-mail relays — see
// backend/supabase/sql/012_relay_rate_limit.sql. Only a SHA-256 hash of the
// sender's IP is stored, for at most a day.

import { createClient } from "npm:@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL");
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

// Per sender per hour, and per relay per day (keeps the Resend quota safe).
const PER_SENDER_PER_HOUR = 10;
const PER_RELAY_PER_DAY = 300;

async function sha256Hex(value: string): Promise<string> {
  const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(value));
  return Array.from(new Uint8Array(digest), (b) => b.toString(16).padStart(2, "0")).join("");
}

/// `true` = go ahead and send. Fails open (logs, allows) when the limiter
/// itself is unavailable, e.g. before 012 has been run.
export async function allowRelay(req: Request, bucket: string): Promise<boolean> {
  if (!SUPABASE_URL || !SERVICE_ROLE_KEY) {
    console.error("Rate limit skipped: SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY not set");
    return true;
  }
  const ip = (req.headers.get("x-forwarded-for") ?? "").split(",")[0].trim() || "unknown";
  const keyHash = await sha256Hex(`${bucket}:${ip}`);

  const supabase = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);
  const { data, error } = await supabase.rpc("relay_allow", {
    p_bucket: bucket,
    p_key_hash: keyHash,
    p_per_key: PER_SENDER_PER_HOUR,
    p_total: PER_RELAY_PER_DAY,
    p_window: "1 hour",
  });
  if (error) {
    console.error("Rate limit skipped: relay_allow failed:", error);
    return true;
  }
  return data === true;
}
