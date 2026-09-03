import { defineAgent } from "eve";

const configuredModel = process.env.EVE_MODEL?.trim();
const model = configuredModel || "openai/gpt-5.6-luna";

console.info(
  `[foreman] model=${model} source=${configuredModel ? "EVE_MODEL" : "default (EVE_MODEL is unset)"}`,
);

export default defineAgent({
  model,

  // Bound accidental or adversarial sessions. Eve pauses interactive sessions
  // at these limits and asks the caller whether to continue.
  limits: {
    maxInputTokensPerSession: 200_000,
    maxOutputTokensPerSession: 20_000,
  },

  // Self-hosted durability: back session state, queues, hooks, and streams
  // with the Postgres Workflow world instead of Vercel Workflow.
  // Credentials/options come from WORKFLOW_POSTGRES_URL at runtime.
  experimental: {
    workflow: {
      world: "@workflow/world-postgres",
    },
  },

  // Keep the world package external so graphile-worker and pg remain normal
  // runtime dependencies in the compiled host.
  build: {
    externalDependencies: ["@workflow/world-postgres"],
  },
});
