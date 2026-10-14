// Receives a recorded voice message from the Slow Down Rádijo app
// (multipart/form-data, field name "audio") and relays it as an email
// attachment via Resend to the station's inbox. The app never talks to
// Resend directly — RESEND_API_KEY only ever lives in this function's
// environment (set via `supabase secrets set`), never in client code.

import { allowRelay } from "../_shared/rate-limit.ts";

const RESEND_API_KEY = Deno.env.get("RESEND_API_KEY");
const RECIPIENT_EMAIL = "jsem@radekschenk.cz";
// A 1-minute mono AAC clip at the app's recording settings is well under
// 1 MB — 5 MB leaves headroom without letting the endpoint be used to
// relay arbitrarily large attachments.
const MAX_FILE_BYTES = 5 * 1024 * 1024;

function jsonResponse(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return jsonResponse({ error: "Method not allowed" }, 405);
  }

  if (!RESEND_API_KEY) {
    console.error("RESEND_API_KEY secret is not set");
    return jsonResponse({ error: "Server misconfigured" }, 500);
  }

  let form: FormData;
  try {
    form = await req.formData();
  } catch {
    return jsonResponse({ error: 'Expected multipart/form-data' }, 400);
  }

  const audio = form.get("audio");
  if (!(audio instanceof File)) {
    return jsonResponse({ error: 'Missing "audio" file field' }, 400);
  }
  if (audio.size === 0) {
    return jsonResponse({ error: "Empty file" }, 400);
  }
  if (audio.size > MAX_FILE_BYTES) {
    return jsonResponse({ error: "File too large" }, 413);
  }

  const bytes = new Uint8Array(await audio.arrayBuffer());
  // The app records MPEG-4 audio (.m4a), which carries "ftyp" at byte 4.
  // Anything else is not a voice message and must not reach the inbox.
  if (bytes.length < 8 || new TextDecoder().decode(bytes.subarray(4, 8)) !== "ftyp") {
    return jsonResponse({ error: "Unsupported audio format" }, 415);
  }

  if (!(await allowRelay(req, "voice"))) {
    return jsonResponse({ error: "Too many messages, try again later" }, 429);
  }

  const base64 = btoa(Array.from(bytes, (b) => String.fromCharCode(b)).join(""));

  const resendResponse = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${RESEND_API_KEY}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      // Requires a domain verified in Resend — see README. Swap this for
      // "onboarding@resend.dev" while testing before verifying a domain.
      from: "Slow Down Rádijo <vzkaz@radekschenk.cz>",
      to: [RECIPIENT_EMAIL],
      subject: "Vzkaz do rádia ze Slow Down Rádijo appky",
      text: "Ahoj, posílám vzkaz pro rádio (nahrávka v příloze).",
      attachments: [
        {
          // Fixed name: the sender doesn't get to choose what the
          // attachment is called (e.g. "faktura.exe").
          filename: "vzkaz.m4a",
          content: base64,
        },
      ],
    }),
  });

  if (!resendResponse.ok) {
    const detail = await resendResponse.text();
    console.error("Resend error:", resendResponse.status, detail);
    return jsonResponse({ error: "Failed to send email" }, 502);
  }

  return jsonResponse({ success: true }, 200);
});
