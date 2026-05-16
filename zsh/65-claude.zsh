# ============================================================================
# Claude-specific configuration and functions
# ============================================================================

# Source Claude functions if they exist
if [[ -f ~/.dotfiles/claude/claude-functions.zsh ]]; then
    source ~/.dotfiles/claude/claude-functions.zsh
fi

# ccx: source shell wrapper (profile dispatcher + CLAUDE_CONFIG_DIR export)
if [[ -f "$HOME/Projects/ccx/shell/ccx.zsh" ]]; then
    source "$HOME/Projects/ccx/shell/ccx.zsh"
fi

# Claude environment variables
export CLAUDE_PROJECT_ROOT="${HOME}/projects"
export CLAUDE_PYTHON_VERSION="3.13"
export UV_PYTHON_PREFERENCE="only-managed"

# Claude Code privacy / data-collection opt-outs.
# Mirrored in settings.json (env block) for defense in depth:
# settings.json applies them inside the claude process, the exports below put
# them in the shell so they are set BEFORE claude starts and visible in `env`.
#
# NOTE: CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC is intentionally NOT set here:
# it bundles DISABLE_AUTOUPDATER among other flags, and we want auto-updates
# on. The four individual flags below cover the same telemetry/error/feedback
# surface without blocking the auto-updater.
export DISABLE_TELEMETRY=1                             # Statsig (operational metrics)
export DISABLE_ERROR_REPORTING=1                       # Sentry (crash/error reports)
export DISABLE_BUG_COMMAND=1                           # legacy name of /bug
export DISABLE_FEEDBACK_COMMAND=1                      # /feedback (would upload full transcript)
export CLAUDE_CODE_DISABLE_FEEDBACK_SURVEY=1           # "How is Claude doing?" survey
export DISABLE_NON_ESSENTIAL_MODEL_CALLS=1             # no background tips/banter LLM calls
export CLAUDECODE=1                                    # marker that we're running inside Claude Code

# Thinking / effort overrides.
# Mirrored in settings.json (env block) for defense in depth:
# settings.json applies them inside the claude process, the exports below put
# them in the shell so they are set BEFORE claude starts and visible in `env`.
# export MAX_THINKING_TOKENS=63999                     # REMOVED: forces fixed budget, disables adaptive thinking
export CLAUDE_CODE_MAX_OUTPUT_TOKENS=64000             # max output tokens per response
# export CLAUDE_CODE_DISABLE_ADAPTIVE_THINKING=1       # REMOVED: prevents server from downscaling budget
export CLAUDE_CODE_ALWAYS_ENABLE_EFFORT=1              # force effort feature on for all models (redundant on 4.6, kept for defense in depth)
# export CLAUDE_CODE_EFFORT_LEVEL=xhigh                # REMOVED: env var blocks per-session /effort max override; default now lives in settings.json effortLevel: "xhigh"
export CLAUDE_CODE_NO_FLICKER=1                        # disable terminal flicker on redraw
export CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1          # enable experimental agent teams

# Model selection.
export CLAUDE_CODE_SUBAGENT_MODEL=claude-opus-4-7              # subagents use Opus
export ANTHROPIC_DEFAULT_OPUS_MODEL="claude-opus-4-7[1m]"      # 1M context Opus
export ANTHROPIC_DEFAULT_SONNET_MODEL="claude-sonnet-4-6"      # 1M context Sonnet

# Tool / runtime behavior.
export ENABLE_LSP_TOOL=1                               # enable LSP tool
export CLAUDE_ENABLE_STREAM_WATCHDOG=1                 # watchdog for stalled streams (off by default, added v2.1.84)
export CLAUDE_STREAM_IDLE_TIMEOUT_MS=600000            # 10 min threshold; floor 15000, default 90000
# export CLAUDE_CODE_AUTO_BACKGROUND_TASKS=1           # REMOVED: strongest single correlator in #25979
export CLAUDE_CODE_RESUME_INTERRUPTED_TURN=1           # resume turns interrupted mid-stream
# export CLAUDE_CODE_EMIT_SESSION_STATE_EVENTS=1       # emit idle/running session state events
export BASH_DEFAULT_TIMEOUT_MS=1800000                 # 30 min default for Bash tool
export BASH_MAX_TIMEOUT_MS=7200000                     # 2 hr max for training runs
