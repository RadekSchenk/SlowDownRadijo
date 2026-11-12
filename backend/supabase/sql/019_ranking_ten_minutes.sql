-- A listener counts towards the leaderboard (and the 20 listeners that
-- unlock it) only after 10 minutes of listening, not 1. Xcode runs,
-- simulators and App Review devices listen for a minute or two and had
-- unlocked the leaderboard on 11 Nov 2026 with only a handful of real
-- listeners. Applied to production on 12 Nov 2026; safe to re-run.

update stats_config set min_listener_seconds = 600;
