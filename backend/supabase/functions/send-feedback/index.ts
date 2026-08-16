// Receives an in-app feedback message from the Slow Down Rádijo app
// (JSON: { message, device }) and relays it as an email via Resend to the
// station's inbox. Mirrors send-voice-message's relay pattern — the app
// never talks to Resend directly; RESEND_API_KEY only ever lives in this
// function's environment.

const RESEND_API_KEY = Deno.env.get("RESEND_API_KEY");
const RECIPIENT_EMAIL = "jsem@radekschenk.cz";
const MAX_MESSAGE_LENGTH = 4000;

interface DeviceInfo {
  appVersion?: string;
  buildNumber?: string;
  osVersion?: string;
  deviceModel?: string;
  appLanguage?: string;
  appearance?: string;
}

function jsonResponse(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

function escapeHtml(value: string): string {
  return value
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;");
}

function deviceInfoLines(device: DeviceInfo | undefined): string {
  if (!device) return "(neznámé zařízení)";
  const rows: [string, string | undefined][] = [
    ["Verze appky", device.appVersion && device.buildNumber ? `${device.appVersion} (${device.buildNumber})` : device.appVersion],
    ["iOS", device.osVersion],
    ["Model", device.deviceModel],
    ["Jazyk appky", device.appLanguage],
    ["Vzhled", device.appearance],
  ];
  return rows
    .filter(([, value]) => !!value)
    .map(([label, value]) => `${label}: ${value}`)
    .join("\n");
}

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return jsonResponse({ error: "Method not allowed" }, 405);
  }

  if (!RESEND_API_KEY) {
    console.error("RESEND_API_KEY secret is not set");
    return jsonResponse({ error: "Server misconfigured" }, 500);
  }

  let payload: { message?: string; device?: DeviceInfo };
  try {
    payload = await req.json();
  } catch {
    return jsonResponse({ error: "Expected JSON body" }, 400);
  }

  const message = payload.message?.trim();
  if (!message) {
    return jsonResponse({ error: "Missing message" }, 400);
  }
  if (message.length > MAX_MESSAGE_LENGTH) {
    return jsonResponse({ error: "Message too long" }, 413);
  }

  const deviceBlock = deviceInfoLines(payload.device);
  const text = `${message}\n\n---\n${deviceBlock}`;
  const html = `<p>${escapeHtml(message).replace(/\n/g, "<br>")}</p><hr><pre>${escapeHtml(deviceBlock)}</pre>`;

  const resendResponse = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${RESEND_API_KEY}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      from: "Slow Down Rádijo <vzkaz@radekschenk.cz>",
      to: [RECIPIENT_EMAIL],
      subject: "Zpětná vazba ze Slow Down Rádijo appky",
      text,
      html,
    }),
  });

  if (!resendResponse.ok) {
    const detail = await resendResponse.text();
    console.error("Resend error:", resendResponse.status, detail);
    return jsonResponse({ error: "Failed to send email" }, 502);
  }

  return jsonResponse({ success: true }, 200);
});
