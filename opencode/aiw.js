// aiw — adapter OpenCode. Tłumaczy zdarzenia OpenCode na format hooków Claude Code
// i wywołuje te same skrypty (~/.claude/ai-workflow/hooks), więc reguły są w jednym miejscu.
import { spawn } from "node:child_process"
import { homedir } from "node:os"
import { join } from "node:path"

const HOOKS = join(homedir(), ".claude/ai-workflow/hooks")

function runHook(script, payload, dir) {
  return new Promise((resolve) => {
    const child = spawn(join(HOOKS, script), [], {
      cwd: dir,
      env: { ...process.env, CLAUDE_PROJECT_DIR: dir },
    })
    let stdout = ""
    let stderr = ""
    child.stdout.on("data", (d) => (stdout += d))
    child.stderr.on("data", (d) => (stderr += d))
    child.on("error", () => resolve({ code: 0, stdout: "", stderr: "" }))
    child.on("close", (code) => resolve({ code, stdout, stderr }))
    child.stdin.end(JSON.stringify(payload))
  })
}

function parseJson(text) {
  try {
    return JSON.parse(text)
  } catch {
    return null
  }
}

// Ścieżki plików z argumentów narzędzia (edit/write: filePath, apply_patch: nagłówki w patchText).
function editedPaths(args) {
  const paths = []
  if (args?.filePath) paths.push(args.filePath)
  if (typeof args?.patchText === "string") {
    for (const m of args.patchText.matchAll(/^\*\*\* (?:Add File|Update File|Delete File|Move to): (.+)$/gm)) {
      paths.push(m[1].trim())
    }
  }
  return paths
}

export const AiwPlugin = async ({ client, directory }) => {
  const stopRunning = new Set()

  return {
    "tool.execute.before": async (input, output) => {
      const payloads =
        input.tool === "bash"
          ? [{ tool_name: "Bash", tool_input: { command: output.args?.command ?? "" } }]
          : editedPaths(output.args).map((p) => ({ tool_name: "Edit", tool_input: { file_path: p } }))
      for (const payload of payloads) {
        const res = await runHook("pre-tool-use.sh", payload, directory)
        const decision = parseJson(res.stdout)?.hookSpecificOutput
        if (decision?.permissionDecision === "deny") throw new Error(decision.permissionDecisionReason)
      }
    },

    "tool.execute.after": async (input, output) => {
      for (const p of editedPaths(input.args)) {
        const res = await runHook("post-tool-use.sh", { tool_name: "Edit", tool_input: { file_path: p } }, directory)
        if (res.code === 2 && res.stderr) output.output = `${output.output ?? ""}\n\n${res.stderr}`
      }
    },

    // Odpowiednik Stop hooka: gdy agent kończy pracę, uruchom weryfikację i w razie
    // niepowodzenia odeślij go do poprawek nowym promptem.
    event: async ({ event }) => {
      if (event.type !== "session.idle") return
      const sessionID = event.properties?.sessionID
      if (!sessionID || stopRunning.has(sessionID)) return

      const session = await client.session.get({ path: { id: sessionID } }).catch(() => null)
      if (session?.data?.parentID) return // subagent (np. /audit) — weryfikujemy tylko główną sesję

      stopRunning.add(sessionID)
      try {
        const res = await runHook("stop.sh", { hook_event_name: "Stop", session_id: sessionID }, directory)
        const out = parseJson(res.stdout)
        if (out?.systemMessage) {
          const variant = out.systemMessage.startsWith("✅") ? "success" : "error"
          await client.tui.showToast({ body: { message: out.systemMessage, variant } }).catch(() => {})
        }
        if (out?.decision === "block") {
          client.session
            .prompt({ path: { id: sessionID }, body: { parts: [{ type: "text", text: `[aiw] ${out.reason}` }] } })
            .catch(() => {})
        }
      } finally {
        stopRunning.delete(sessionID)
      }
    },
  }
}
