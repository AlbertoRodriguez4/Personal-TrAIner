import { createLovableAiGatewayProvider } from "@/lib/ai-gateway.server";
import { createFileRoute } from "@tanstack/react-router";
import { convertToModelMessages, streamText, type UIMessage } from "ai";

type ChatRequestBody = { messages?: unknown };

const SYSTEM_PROMPT = `Eres "Personal TrAIner", el coach de IA dentro de una app premium de fitness y salud.
Hablas en español, tono cercano pero experto. Respuestas breves, accionables y motivadoras.
Conocimientos: entrenamiento de fuerza/cardio, nutrición y macros, recuperación, biometría (FC, HRV, sueño),
análisis de datos de Mi Band / Xiaomi. No das diagnósticos médicos: deriva al profesional cuando proceda.
Usa listas y negritas con moderación. Evita emojis salvo que aporten claridad.`;

export const Route = createFileRoute("/api/chat")({
  server: {
    handlers: {
      POST: async ({ request }) => {
        const { messages } = (await request.json()) as ChatRequestBody;
        if (!Array.isArray(messages)) {
          return new Response("Messages are required", { status: 400 });
        }

        const key = process.env.LOVABLE_API_KEY;
        if (!key) return new Response("Missing LOVABLE_API_KEY", { status: 500 });

        const gateway = createLovableAiGatewayProvider(key);
        const result = streamText({
          model: gateway("google/gemini-3-flash-preview"),
          system: SYSTEM_PROMPT,
          messages: await convertToModelMessages(messages as UIMessage[]),
        });

        return result.toUIMessageStreamResponse({
          originalMessages: messages as UIMessage[],
        });
      },
    },
  },
});