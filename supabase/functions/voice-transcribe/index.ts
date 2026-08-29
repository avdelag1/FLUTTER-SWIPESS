import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { decode } from "https://deno.land/std@0.168.0/encoding/base64.ts";

const ALLOWED_ORIGIN = Deno.env.get("ALLOWED_ORIGIN") || "*";
const corsHeaders = {
  "Access-Control-Allow-Origin": ALLOWED_ORIGIN,
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const GROQ_API_KEY = Deno.env.get("GROQ_API_KEY") || "";
const MAX_AUDIO_B64_BYTES = 10 * 1024 * 1024;
const TRANSCRIPTION_PROMPT =
  "Transcribe exactly what the speaker says in the requested recognition language. Preserve names, numbers, places, brand terms, and any words the speaker actually says in another language, but never translate, summarize, or invent missing words. Common SWIPESS vocabulary includes Swipess, Tulum, Riviera Maya, WhatsApp, yacht, property, listing, events, workers, lawyer, legal, motorcycles, bicycles, seekers, roommates, and Mapbox.";

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { headers: corsHeaders });
  }

  const declaredLen = Number(req.headers.get("content-length") || "0");
  if (declaredLen > MAX_AUDIO_B64_BYTES) {
    return new Response(JSON.stringify({ error: "Audio payload too large." }), {
      status: 413,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  try {
    if (!GROQ_API_KEY) {
      throw new Error("GROQ_API_KEY is not configured.");
    }

    const { audio, mimeType, language } = await req.json();
    if (!audio) throw new Error("No audio provided.");

    if (typeof audio !== "string" || audio.length > MAX_AUDIO_B64_BYTES) {
      return new Response(
        JSON.stringify({ error: "Audio payload too large or invalid." }),
        {
          status: 413,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    const bytes = decode(audio);
    const fileExt = mimeType?.includes("mp4")
      ? "m4a"
      : mimeType?.includes("wav")
      ? "wav"
      : mimeType?.includes("ogg")
      ? "ogg"
      : mimeType?.includes("mpeg")
      ? "mp3"
      : "webm";
    const file = new File([bytes], `audio.${fileExt}`, {
      type: mimeType || "audio/webm",
    });

    const formData = new FormData();
    // Accuracy is more important than the small Turbo latency advantage for
    // short dashboard queries. Large V3 also follows an explicit language hint
    // consistently across iOS recordings.
    formData.append("file", file);
    formData.append("model", "whisper-large-v3");
    formData.append("temperature", "0");
    formData.append("response_format", "json");
    formData.append("prompt", TRANSCRIPTION_PROMPT);

    // No auto detector: callers select a language explicitly. English is the
    // safe fallback for older clients that do not yet send the field.
    const languageHint = typeof language === "string" && language.trim()
      ? language.trim().toLowerCase()
      : "en-us";
    formData.append("language", languageHint.split("-")[0]);

    const response = await fetch(
      "https://api.groq.com/openai/v1/audio/transcriptions",
      {
        method: "POST",
        headers: { Authorization: `Bearer ${GROQ_API_KEY}` },
        body: formData,
      },
    );

    if (!response.ok) {
      const err = await response.text();
      console.error("Groq Whisper API Error:", err);
      throw new Error(`Transcription failed (${response.status}).`);
    }

    const data = await response.json();
    const text = typeof data?.text === "string" ? data.text.trim() : "";

    return new Response(JSON.stringify({ text }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (err) {
    const message = err instanceof Error ? err.message : "Unknown error";
    console.error("Voice transcription error:", message);
    return new Response(JSON.stringify({ error: message }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
