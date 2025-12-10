use serde::Deserialize;
use std::env;
use std::fs;
use std::io::{self, Read, Write};
use std::path::{Path, PathBuf};
use std::process::{Command, ExitCode, Stdio};

// Pre-compiled regex patterns for maximum performance
mod patterns {
    use once_cell::sync::Lazy;
    use regex::Regex;

    // Secret patterns
    pub static AWS_KEY: Lazy<Regex> = Lazy::new(|| Regex::new(r"AKIA[0-9A-Z]{16}").unwrap());
    pub static OPENAI_KEY: Lazy<Regex> = Lazy::new(|| Regex::new(r"sk-[a-zA-Z0-9]{48}").unwrap());
    pub static OPENAI_PROJ: Lazy<Regex> =
        Lazy::new(|| Regex::new(r"sk-proj-[a-zA-Z0-9\-]{80,}").unwrap());
    pub static GITHUB_PAT: Lazy<Regex> = Lazy::new(|| Regex::new(r"ghp_[a-zA-Z0-9]{36}").unwrap());
    pub static GITHUB_OAUTH: Lazy<Regex> =
        Lazy::new(|| Regex::new(r"gho_[a-zA-Z0-9]{36}").unwrap());
    pub static GITHUB_PAT_FINE: Lazy<Regex> =
        Lazy::new(|| Regex::new(r"github_pat_[a-zA-Z0-9]{22}_[a-zA-Z0-9]{59}").unwrap());
    pub static SLACK_TOKEN: Lazy<Regex> =
        Lazy::new(|| Regex::new(r"xox[baprs]-[a-zA-Z0-9\-]+").unwrap());
    pub static STRIPE_LIVE: Lazy<Regex> =
        Lazy::new(|| Regex::new(r"sk_live_[a-zA-Z0-9]+").unwrap());
    pub static STRIPE_RESTRICTED: Lazy<Regex> =
        Lazy::new(|| Regex::new(r"rk_live_[a-zA-Z0-9]+").unwrap());

    pub static SECRET_PATTERNS: &[&Lazy<Regex>] = &[
        &AWS_KEY,
        &OPENAI_KEY,
        &OPENAI_PROJ,
        &GITHUB_PAT,
        &GITHUB_OAUTH,
        &GITHUB_PAT_FINE,
        &SLACK_TOKEN,
        &STRIPE_LIVE,
        &STRIPE_RESTRICTED,
    ];

    // Dangerous command patterns
    pub static RM_ROOT: Lazy<Regex> = Lazy::new(|| Regex::new(r"rm -rf /($|[^a-zA-Z])").unwrap());
    pub static RM_ROOT_STAR: Lazy<Regex> = Lazy::new(|| Regex::new(r"rm -rf /\*").unwrap());
    pub static RM_HOME: Lazy<Regex> = Lazy::new(|| Regex::new(r"rm -rf ~").unwrap());
    pub static RM_HOME_STAR: Lazy<Regex> = Lazy::new(|| Regex::new(r"rm -rf ~/\*").unwrap());
    pub static RM_HOME_VAR: Lazy<Regex> = Lazy::new(|| Regex::new(r"rm -rf \$HOME").unwrap());
    pub static RM_DOT: Lazy<Regex> = Lazy::new(|| Regex::new(r"rm -rf \.$").unwrap());
    pub static RM_DOTDOT: Lazy<Regex> = Lazy::new(|| Regex::new(r"rm -rf \.\.").unwrap());
    pub static RM_DOT_STAR: Lazy<Regex> = Lazy::new(|| Regex::new(r"rm -rf \./\*").unwrap());
    pub static MKFS: Lazy<Regex> = Lazy::new(|| Regex::new(r"mkfs").unwrap());
    pub static DD_DEV: Lazy<Regex> = Lazy::new(|| Regex::new(r"dd if=.* of=/dev/").unwrap());
    pub static WRITE_DEV: Lazy<Regex> = Lazy::new(|| Regex::new(r"> /dev/sd").unwrap());
    pub static CHMOD_777: Lazy<Regex> = Lazy::new(|| Regex::new(r"chmod -R 777 /").unwrap());
    pub static CHOWN_ROOT: Lazy<Regex> = Lazy::new(|| Regex::new(r"chown -R .* /").unwrap());
    pub static FORK_BOMB: Lazy<Regex> = Lazy::new(|| Regex::new(r":\(\)\{ :\|:& \};:").unwrap());
    pub static FORK_WHILE: Lazy<Regex> = Lazy::new(|| Regex::new(r"fork while fork").unwrap());
    pub static HISTORY_CLEAR: Lazy<Regex> = Lazy::new(|| Regex::new(r"history -c").unwrap());
    pub static SHRED_HIST: Lazy<Regex> = Lazy::new(|| Regex::new(r"shred.*history").unwrap());
    pub static SHRED_BASH: Lazy<Regex> = Lazy::new(|| Regex::new(r"shred.*bash_history").unwrap());
    pub static FORCE_MAIN: Lazy<Regex> =
        Lazy::new(|| Regex::new(r"git push.*--force.*main").unwrap());
    pub static FORCE_MASTER: Lazy<Regex> =
        Lazy::new(|| Regex::new(r"git push.*--force.*master").unwrap());
    pub static FORCE_F_MAIN: Lazy<Regex> = Lazy::new(|| Regex::new(r"git push.*-f.*main").unwrap());
    pub static FORCE_F_MASTER: Lazy<Regex> =
        Lazy::new(|| Regex::new(r"git push.*-f.*master").unwrap());
    pub static RESET_MAIN: Lazy<Regex> =
        Lazy::new(|| Regex::new(r"git reset --hard.*origin/main").unwrap());
    pub static RESET_MASTER: Lazy<Regex> =
        Lazy::new(|| Regex::new(r"git reset --hard.*origin/master").unwrap());
    pub static RM_VAR: Lazy<Regex> = Lazy::new(|| Regex::new(r"rm\s+-rf?\s+.*\$").unwrap());

    pub static DANGEROUS_PATTERNS: &[&Lazy<Regex>] = &[
        &RM_ROOT,
        &RM_ROOT_STAR,
        &RM_HOME,
        &RM_HOME_STAR,
        &RM_HOME_VAR,
        &RM_DOT,
        &RM_DOTDOT,
        &RM_DOT_STAR,
        &MKFS,
        &DD_DEV,
        &WRITE_DEV,
        &CHMOD_777,
        &CHOWN_ROOT,
        &FORK_BOMB,
        &FORK_WHILE,
        &HISTORY_CLEAR,
        &SHRED_HIST,
        &SHRED_BASH,
        &FORCE_MAIN,
        &FORCE_MASTER,
        &FORCE_F_MAIN,
        &FORCE_F_MASTER,
        &RESET_MAIN,
        &RESET_MASTER,
    ];

    // Commit/branch patterns
    pub static COMMIT_MSG: Lazy<Regex> =
        Lazy::new(|| Regex::new(r#"-m\s*["']([^"']+)["']"#).unwrap());
    pub static CONVENTIONAL: Lazy<Regex> = Lazy::new(|| {
        Regex::new(r"^(feat|fix|docs|style|refactor|perf|test|chore|ci|build|revert)(\([a-zA-Z0-9_-]+\))?: .+").unwrap()
    });
    pub static BRANCH_CREATE: Lazy<Regex> =
        Lazy::new(|| Regex::new(r"(checkout\s+-b|switch\s+-c)\s+(\S+)").unwrap());
    pub static BRANCH_PROTECTED: Lazy<Regex> =
        Lazy::new(|| Regex::new(r"^(main|master|develop|release/.+|hotfix/.+)$").unwrap());
    pub static BRANCH_NAMING: Lazy<Regex> = Lazy::new(|| {
        Regex::new(r"^(feat|fix|refactor|docs|test|chore|ci|build|perf|revert)/[a-z0-9-]+$")
            .unwrap()
    });

    // JAX patterns
    pub static EINSUM: Lazy<Regex> =
        Lazy::new(|| Regex::new(r#"jnp\.einsum\s*\(\s*["']([^"']+)["']"#).unwrap());
    pub static VMAP: Lazy<Regex> =
        Lazy::new(|| Regex::new(r"jax\.(vmap|pmap)\s*\(\s*\w+\s*\)").unwrap());
}

#[derive(Debug, Deserialize)]
struct HookInput {
    tool_name: Option<String>,
    tool_input: Option<ToolInput>,
    #[allow(dead_code)]
    cwd: Option<String>,
    session_id: Option<String>,
    #[serde(alias = "user_prompt")]
    prompt: Option<String>,
    hook_event_name: Option<String>,
    stop_hook_reason: Option<String>,
}

#[derive(Debug, Deserialize)]
struct ToolInput {
    file_path: Option<String>,
    content: Option<String>,
    new_string: Option<String>,
    #[allow(dead_code)]
    old_string: Option<String>,
    command: Option<String>,
    pattern: Option<String>,
}

struct HookResult {
    exit_code: u8,
    stderr_messages: Vec<String>,
    stdout_json: Option<String>,
}

impl HookResult {
    fn ok() -> Self {
        Self {
            exit_code: 0,
            stderr_messages: Vec::new(),
            stdout_json: None,
        }
    }

    fn warn(msg: impl Into<String>) -> Self {
        Self {
            exit_code: 0,
            stderr_messages: vec![msg.into()],
            stdout_json: None,
        }
    }

    fn block(msg: impl Into<String>) -> Self {
        Self {
            exit_code: 2,
            stderr_messages: vec![msg.into()],
            stdout_json: None,
        }
    }

    fn with_context(json: String) -> Self {
        Self {
            exit_code: 0,
            stderr_messages: Vec::new(),
            stdout_json: Some(json),
        }
    }

    fn merge(mut self, other: Self) -> Self {
        self.stderr_messages.extend(other.stderr_messages);
        if other.exit_code > self.exit_code {
            self.exit_code = other.exit_code;
        }
        if let Some(other_json) = other.stdout_json {
            if let Some(self_json) = &self.stdout_json {
                // Merge additionalContext fields
                if let (Ok(mut self_data), Ok(other_data)) = (
                    serde_json::from_str::<serde_json::Value>(self_json),
                    serde_json::from_str::<serde_json::Value>(&other_json),
                ) {
                    if let (Some(self_ctx), Some(other_ctx)) = (
                        self_data.get("additionalContext").and_then(|v| v.as_str()),
                        other_data.get("additionalContext").and_then(|v| v.as_str()),
                    ) {
                        self_data["additionalContext"] =
                            serde_json::Value::String(format!("{}\n\n{}", self_ctx, other_ctx));
                        self.stdout_json = Some(self_data.to_string());
                    } else {
                        self.stdout_json = Some(other_json);
                    }
                } else {
                    self.stdout_json = Some(other_json);
                }
            } else {
                self.stdout_json = Some(other_json);
            }
        }
        self
    }
}

// Run command with timeout (5 seconds default)
fn run_cmd(cmd: &str, args: &[&str], cwd: Option<&Path>) -> Option<std::process::Output> {
    let mut command = Command::new(cmd);
    command
        .args(args)
        .stdout(Stdio::piped())
        .stderr(Stdio::piped());
    if let Some(dir) = cwd {
        command.current_dir(dir);
    }
    command.output().ok()
}

fn main() -> ExitCode {
    let args: Vec<String> = env::args().collect();
    if args.len() < 2 {
        eprintln!("Usage: claude-hooks <hook-name>");
        return ExitCode::from(1);
    }

    let mut input = String::new();
    if io::stdin().read_to_string(&mut input).is_err() {
        return ExitCode::from(0);
    }

    let hook_input: HookInput = match serde_json::from_str(&input) {
        Ok(v) => v,
        Err(_) => return ExitCode::from(0),
    };

    let result = match args[1].as_str() {
        "protect-files" => protect_files(&hook_input),
        "large-file-check" => large_file_check(&hook_input),
        "git-status-check" => git_status_check(&hook_input),
        "branch-protection" => branch_protection(&hook_input),
        "test-file-guard" => test_file_guard(&hook_input),
        "verify-api-calls" => verify_api_calls(&hook_input),
        "dangerous-command" => dangerous_command(&hook_input),
        "validate-commit" => validate_commit(&hook_input),
        "format-on-save" => format_on_save(&hook_input),
        "typecheck" => typecheck(&hook_input),
        "jax-shape-check" => jax_shape_check(&hook_input),
        "import-cycle-check" => import_cycle_check(&hook_input),
        "session-logger" => session_logger(&hook_input),
        "inject-context" => inject_context(&hook_input),
        "context7-docs" => context7_docs(&hook_input),
        "notify-done" => notify_done(&hook_input),
        "pre-edit" => pre_edit_combined(&hook_input),
        "post-edit" => post_edit_combined(&hook_input),
        "pre-bash" => pre_bash_combined(&hook_input),
        "user-prompt" => user_prompt_combined(&hook_input),
        _ => HookResult::ok(),
    };

    for msg in &result.stderr_messages {
        eprintln!("{}", msg);
    }
    if let Some(json) = result.stdout_json {
        println!("{}", json);
    }

    ExitCode::from(result.exit_code)
}

// Combined hooks for better performance
fn pre_edit_combined(input: &HookInput) -> HookResult {
    let mut result = HookResult::ok();
    result = result.merge(protect_files(input));
    if result.exit_code > 0 {
        return result;
    }
    result = result.merge(large_file_check(input));
    if result.exit_code > 0 {
        return result;
    }
    result = result.merge(git_status_check(input));
    result = result.merge(branch_protection(input));
    result = result.merge(test_file_guard(input));
    result = result.merge(verify_api_calls(input));
    result
}

fn post_edit_combined(input: &HookInput) -> HookResult {
    let mut result = HookResult::ok();
    result = result.merge(format_on_save(input));
    result = result.merge(typecheck(input));
    result = result.merge(jax_shape_check(input));
    result = result.merge(import_cycle_check(input));
    result = result.merge(session_logger(input));
    result
}

fn pre_bash_combined(input: &HookInput) -> HookResult {
    let mut result = HookResult::ok();
    result = result.merge(dangerous_command(input));
    if result.exit_code > 0 {
        return result;
    }
    result = result.merge(validate_commit(input));
    result
}

fn user_prompt_combined(input: &HookInput) -> HookResult {
    let mut result = HookResult::ok();
    result = result.merge(inject_context(input));
    result = result.merge(context7_docs(input));
    result
}

// Fast glob matching without regex conversion
fn glob_match(pattern: &str, path: &str) -> bool {
    let mut pattern_chars = pattern.chars().peekable();
    let mut path_chars = path.chars().peekable();

    while let Some(p) = pattern_chars.next() {
        match p {
            '*' => {
                // Check for **
                if pattern_chars.peek() == Some(&'*') {
                    pattern_chars.next();
                    // ** matches any path segment
                    let remaining: String = pattern_chars.collect();
                    if remaining.is_empty() {
                        return true;
                    }
                    let remaining = remaining.trim_start_matches('/');
                    for (i, _) in path_chars.clone().enumerate() {
                        let remaining_path: String = path_chars.clone().skip(i).collect();
                        if glob_match(remaining, &remaining_path) {
                            return true;
                        }
                    }
                    return false;
                }
                // * matches anything except /
                let next_pattern: String = pattern_chars.collect();
                if next_pattern.is_empty() {
                    return !path_chars.any(|c| c == '/');
                }
                for (i, c) in path_chars.clone().enumerate() {
                    if c == '/' {
                        break;
                    }
                    let remaining_path: String = path_chars.clone().skip(i).collect();
                    if glob_match(&next_pattern, &remaining_path) {
                        return true;
                    }
                }
                return glob_match(&next_pattern, &path_chars.collect::<String>());
            }
            '?' => {
                if path_chars.next().is_none() {
                    return false;
                }
            }
            c => {
                if path_chars.next() != Some(c) {
                    return false;
                }
            }
        }
    }
    path_chars.next().is_none()
}

// Protected file patterns
const PROTECTED_PATTERNS: &[&str] = &[
    "*.env",
    "*.env.*",
    "*/.env",
    "*/.env.*",
    "*credentials*",
    "*secrets*",
    "*.pem",
    "*.key",
    "*.crt",
    "*id_rsa*",
    "*id_ed25519*",
    ".git/*",
    "*/.git/*",
    "package-lock.json",
    "yarn.lock",
    "Cargo.lock",
    "uv.lock",
    "poetry.lock",
    ".vscode/settings.json",
    ".idea/*",
];

fn protect_files(input: &HookInput) -> HookResult {
    let tool_name = match &input.tool_name {
        Some(t) if t == "Edit" || t == "Write" => t,
        _ => return HookResult::ok(),
    };

    let file_path = match input.tool_input.as_ref().and_then(|t| t.file_path.as_ref()) {
        Some(p) => p,
        None => return HookResult::ok(),
    };

    // Check protected patterns
    for pattern in PROTECTED_PATTERNS {
        if glob_match(pattern, file_path) {
            return HookResult::block(format!(
                "BLOCKED: Cannot modify protected file: {}\nPattern matched: {}\nIf you need to modify this file, please do so manually.",
                file_path, pattern
            ));
        }
    }

    // Check for secrets in Write content (using pre-compiled patterns)
    if tool_name == "Write" {
        if let Some(content) = input.tool_input.as_ref().and_then(|t| t.content.as_ref()) {
            for pattern in patterns::SECRET_PATTERNS {
                if pattern.is_match(content) {
                    return HookResult::block(
                        "BLOCKED: Potential secret/API key detected in file content\nPlease use environment variables or a secrets manager instead."
                    );
                }
            }
        }
    }

    HookResult::ok()
}

fn large_file_check(input: &HookInput) -> HookResult {
    let tool_name = match &input.tool_name {
        Some(t) => t.as_str(),
        None => return HookResult::ok(),
    };

    match tool_name {
        "Write" => {
            let content = match input.tool_input.as_ref().and_then(|t| t.content.as_ref()) {
                Some(c) => c,
                None => return HookResult::ok(),
            };
            let file_path = input
                .tool_input
                .as_ref()
                .and_then(|t| t.file_path.as_ref())
                .map(|s| s.as_str())
                .unwrap_or("unknown");
            let size = content.len();

            if size > 1_048_576 {
                return HookResult::block(format!(
                    "BLOCKED: File content too large ({}MB)\nThis is likely a mistake. If intentional, write manually.",
                    size / 1_048_576
                ));
            }

            if size > 102_400 {
                return HookResult::warn(format!(
                    "WARNING: Large file write detected\nFile: {}\nSize: {}KB\n\nConsider:\n  - Breaking into smaller files\n  - Using external data storage\n  - Generating programmatically instead of hardcoding",
                    file_path, size / 1024
                ));
            }

            // Check for binary content (sample first 1000 bytes for speed)
            if size > 1000 {
                let sample_size = size.min(4096);
                let non_printable = content
                    .bytes()
                    .take(sample_size)
                    .filter(|&b| b < 32 && b != 9 && b != 10 && b != 13)
                    .count();
                let ratio = (non_printable * 100) / sample_size;
                if ratio > 20 {
                    return HookResult::warn(format!(
                        "WARNING: Content appears to contain binary data ({}% non-printable)\nFile: {}",
                        ratio, file_path
                    ));
                }
            }
        }
        "Edit" => {
            if let Some(new_string) = input
                .tool_input
                .as_ref()
                .and_then(|t| t.new_string.as_ref())
            {
                if new_string.len() > 51_200 {
                    return HookResult::warn(format!(
                        "WARNING: Large edit detected ({}KB replacement)\nConsider breaking into smaller edits.",
                        new_string.len() / 1024
                    ));
                }
            }
        }
        _ => {}
    }

    HookResult::ok()
}

fn git_status_check(input: &HookInput) -> HookResult {
    match &input.tool_name {
        Some(t) if t == "Edit" || t == "Write" => {}
        _ => return HookResult::ok(),
    }

    let file_path = match input.tool_input.as_ref().and_then(|t| t.file_path.as_ref()) {
        Some(p) => p,
        None => return HookResult::ok(),
    };

    let path = Path::new(file_path);
    if !path.exists() {
        return HookResult::ok();
    }

    let git_root = match find_git_root(path) {
        Some(r) => r,
        None => return HookResult::ok(),
    };

    // Check file status
    if let Some(output) = run_cmd(
        "git",
        &["status", "--porcelain", file_path],
        Some(&git_root),
    ) {
        let status = String::from_utf8_lossy(&output.stdout);
        if !status.is_empty() && status.len() >= 2 {
            let status_code = &status[..2];
            match status_code {
                " M" | "MM" | "AM" => {
                    return HookResult::warn(format!(
                        "WARNING: File has uncommitted modifications\nFile: {}\nConsider committing or stashing changes first.",
                        file_path
                    ));
                }
                "??" => {}
                _ => {
                    return HookResult::warn(format!(
                        "WARNING: File has uncommitted changes (status: {})\nFile: {}",
                        status_code.trim(),
                        file_path
                    ));
                }
            }
        }
    }

    // Check total changes
    if let Some(output) = run_cmd("git", &["status", "--porcelain"], Some(&git_root)) {
        let changes = String::from_utf8_lossy(&output.stdout).lines().count();
        if changes > 20 {
            return HookResult::warn(format!(
                "NOTE: Repository has {} uncommitted changes\nConsider committing or stashing before making more changes.",
                changes
            ));
        }
    }

    HookResult::ok()
}

const PROTECTED_BRANCHES: &[&str] = &["main", "master", "production", "prod", "release", "develop"];

fn branch_protection(input: &HookInput) -> HookResult {
    match &input.tool_name {
        Some(t) if t == "Edit" || t == "Write" => {}
        _ => return HookResult::ok(),
    }

    if let Some(output) = run_cmd("git", &["branch", "--show-current"], None) {
        if output.status.success() {
            let branch = String::from_utf8_lossy(&output.stdout).trim().to_string();
            if PROTECTED_BRANCHES.contains(&branch.as_str()) {
                return HookResult::warn(format!(
                    "WARNING: You are on '{}' branch.\nConsider creating a feature branch: git checkout -b feature/your-feature",
                    branch
                ));
            }
        }
    }

    HookResult::ok()
}

fn test_file_guard(input: &HookInput) -> HookResult {
    match &input.tool_name {
        Some(t) if t == "Edit" || t == "Write" => {}
        _ => return HookResult::ok(),
    }

    let file_path = match input.tool_input.as_ref().and_then(|t| t.file_path.as_ref()) {
        Some(p) => p,
        None => return HookResult::ok(),
    };

    // Fast path checks using contains/ends_with (no regex needed)
    let is_test = file_path.contains("test_")
        || file_path.contains("_test.")
        || file_path.contains("/tests/")
        || file_path.ends_with("Test.java")
        || file_path.ends_with("Test.ts")
        || file_path.ends_with("Test.tsx")
        || file_path.ends_with(".test.ts")
        || file_path.ends_with(".test.tsx")
        || file_path.ends_with(".test.js")
        || file_path.ends_with(".spec.ts")
        || file_path.ends_with(".spec.js");

    if is_test {
        return HookResult::warn(
            "NOTE: Editing test file. Remember to run tests before committing.",
        );
    }

    HookResult::ok()
}

const JAX_LIBS: &[&str] = &[
    "jax",
    "jax.numpy",
    "jax.lax",
    "jax.random",
    "jax.nn",
    "flax.nnx",
    "flax.linen",
    "optax",
    "orbax",
    "orbax.checkpoint",
    "jaxtyping",
    "grain",
    "chex",
    "equinox",
    "fiddle",
    "langchain",
    "transformers",
    "anthropic",
    "openai",
];

fn verify_api_calls(input: &HookInput) -> HookResult {
    match &input.tool_name {
        Some(t) if t == "Edit" || t == "Write" => {}
        _ => return HookResult::ok(),
    }

    // Check if it's a Python file (value not used, only for filtering)
    match input.tool_input.as_ref().and_then(|t| t.file_path.as_ref()) {
        Some(p) if p.ends_with(".py") => {}
        _ => return HookResult::ok(),
    }

    let content = input
        .tool_input
        .as_ref()
        .and_then(|t| t.content.as_ref().or(t.new_string.as_ref()))
        .map(|s| s.as_str())
        .unwrap_or("");

    // Fast check using contains instead of regex
    let mut found_libs = Vec::new();
    for lib in JAX_LIBS {
        if content.contains(&format!("from {}", lib))
            || content.contains(&format!("import {}", lib))
        {
            found_libs.push(*lib);
        }
    }

    if !found_libs.is_empty() {
        return HookResult::warn(format!(
            "NOTE: Code uses APIs from: {}\nThese libraries have complex/evolving APIs. Consider verifying function signatures with Context7 MCP if unsure.",
            found_libs.join(", ")
        ));
    }

    HookResult::ok()
}

fn dangerous_command(input: &HookInput) -> HookResult {
    match &input.tool_name {
        Some(t) if t == "Bash" => {}
        _ => return HookResult::ok(),
    }

    let command = match input.tool_input.as_ref().and_then(|t| t.command.as_ref()) {
        Some(c) => c,
        None => return HookResult::ok(),
    };

    // Use pre-compiled patterns
    for pattern in patterns::DANGEROUS_PATTERNS {
        if pattern.is_match(command) {
            return HookResult::block(format!(
                "BLOCKED: Potentially dangerous command detected\nCommand: {}\n\nIf you really need to run this command, please do so manually.",
                command
            ));
        }
    }

    // Warn about rm with variables
    if patterns::RM_VAR.is_match(command) {
        return HookResult::warn(format!(
            "WARNING: rm -rf with variable expansion detected\nCommand: {}\nEnsure the variable is set correctly before proceeding.",
            command
        ));
    }

    // Warn about sudo
    if command.starts_with("sudo ") {
        return HookResult::warn("WARNING: sudo command detected - will require manual approval");
    }

    HookResult::ok()
}

fn validate_commit(input: &HookInput) -> HookResult {
    match &input.tool_name {
        Some(t) if t == "Bash" => {}
        _ => return HookResult::ok(),
    }

    let command = match input.tool_input.as_ref().and_then(|t| t.command.as_ref()) {
        Some(c) => c,
        None => return HookResult::ok(),
    };

    // Check for git commit
    if command.contains("git commit") {
        if let Some(caps) = patterns::COMMIT_MSG.captures(command) {
            let msg = &caps[1];
            if !patterns::CONVENTIONAL.is_match(msg) {
                return HookResult::block(format!(
                    "BLOCKED: Commit message does not follow conventional commits format\n\nExpected format: type(scope): description\n\nValid types: feat, fix, docs, style, refactor, perf, test, chore, ci, build, revert\n\nExample: feat(auth): add OAuth2 login flow\nYour message: {}",
                    msg
                ));
            }

            let subject = msg.lines().next().unwrap_or(msg);
            if subject.len() > 72 {
                return HookResult::warn(format!(
                    "WARNING: Commit subject line is {} chars (recommended <= 50, max 72)",
                    subject.len()
                ));
            }
        }
    }

    // Check branch creation
    if let Some(caps) = patterns::BRANCH_CREATE.captures(command) {
        let branch = &caps[2];
        if !patterns::BRANCH_PROTECTED.is_match(branch) && !patterns::BRANCH_NAMING.is_match(branch)
        {
            return HookResult::block(format!(
                "BLOCKED: Branch name does not follow naming convention\n\nExpected format: type/short-description\nExample: feat/add-oauth-login\nYour branch: {}",
                branch
            ));
        }
    }

    HookResult::ok()
}

fn format_on_save(input: &HookInput) -> HookResult {
    let file_path = match input.tool_input.as_ref().and_then(|t| t.file_path.as_ref()) {
        Some(p) => p,
        None => return HookResult::ok(),
    };

    if !Path::new(file_path).exists() {
        return HookResult::ok();
    }

    // Run formatters based on extension
    if file_path.ends_with(".py") {
        let _ = run_cmd("ruff", &["check", file_path, "--fix", "--quiet"], None);
        let _ = run_cmd("ruff", &["format", file_path, "--quiet"], None);
    } else if file_path.ends_with(".rs") {
        let _ = run_cmd("rustfmt", &[file_path], None);
    } else if file_path.ends_with(".ts")
        || file_path.ends_with(".tsx")
        || file_path.ends_with(".js")
        || file_path.ends_with(".jsx")
        || file_path.ends_with(".json")
    {
        let _ = run_cmd("npx", &["prettier", "--write", file_path], None);
    } else if file_path.ends_with(".md") {
        let _ = run_cmd(
            "npx",
            &["prettier", "--write", file_path, "--prose-wrap=always"],
            None,
        );
    }

    HookResult::ok()
}

fn typecheck(input: &HookInput) -> HookResult {
    let file_path = match input.tool_input.as_ref().and_then(|t| t.file_path.as_ref()) {
        Some(p) => p,
        None => return HookResult::ok(),
    };

    if !Path::new(file_path).exists() {
        return HookResult::ok();
    }

    if file_path.ends_with(".py") {
        typecheck_python(file_path)
    } else if file_path.ends_with(".ts") || file_path.ends_with(".tsx") {
        typecheck_typescript(file_path)
    } else if file_path.ends_with(".rs") {
        typecheck_rust(file_path)
    } else {
        HookResult::ok()
    }
}

fn typecheck_python(file_path: &str) -> HookResult {
    let path = Path::new(file_path);
    let project_root = match find_project_root(path) {
        Some(r) => r,
        None => return HookResult::ok(),
    };

    // Check if mypy is configured
    let has_config = project_root.join("mypy.ini").exists()
        || project_root.join(".mypy.ini").exists()
        || (project_root.join("pyproject.toml").exists() && {
            fs::read_to_string(project_root.join("pyproject.toml"))
                .map(|s| s.contains("[tool.mypy]"))
                .unwrap_or(false)
        });

    if !has_config {
        return HookResult::ok();
    }

    let rel_path = path.strip_prefix(&project_root).unwrap_or(path);
    let rel_path_str = rel_path.to_string_lossy();

    let output = if project_root.join("pyproject.toml").exists() {
        run_cmd(
            "uv",
            &[
                "run",
                "--quiet",
                "mypy",
                &rel_path_str,
                "--no-error-summary",
                "--no-color",
            ],
            Some(&project_root),
        )
    } else {
        run_cmd(
            "mypy",
            &[&rel_path_str, "--no-error-summary", "--no-color"],
            Some(&project_root),
        )
    };

    if let Some(output) = output {
        if !output.status.success() {
            let stdout = String::from_utf8_lossy(&output.stdout);
            let errors: Vec<&str> = stdout
                .lines()
                .filter(|l| l.starts_with(&*rel_path_str))
                .collect();

            if !errors.is_empty() {
                return HookResult::block(format!(
                    "mypy errors in {}:\n{}",
                    file_path,
                    errors.join("\n")
                ));
            }
        }
    }

    HookResult::ok()
}

fn typecheck_typescript(file_path: &str) -> HookResult {
    let path = Path::new(file_path);
    let mut search_dir = path.parent();
    let mut tsconfig = None;

    while let Some(dir) = search_dir {
        let config_path = dir.join("tsconfig.json");
        if config_path.exists() {
            tsconfig = Some(config_path);
            break;
        }
        search_dir = dir.parent();
    }

    let tsconfig = match tsconfig {
        Some(c) => c,
        None => return HookResult::ok(),
    };

    if let Some(output) = run_cmd(
        "npx",
        &["tsc", "--noEmit", "--project", &tsconfig.to_string_lossy()],
        None,
    ) {
        let stdout = String::from_utf8_lossy(&output.stdout);
        let errors: Vec<&str> = stdout
            .lines()
            .filter(|l| l.starts_with(file_path))
            .collect();

        if !errors.is_empty() {
            return HookResult::block(format!(
                "TypeScript errors in {}:\n{}",
                file_path,
                errors.join("\n")
            ));
        }
    }

    HookResult::ok()
}

fn typecheck_rust(file_path: &str) -> HookResult {
    let path = Path::new(file_path);
    let mut search_dir = path.parent();
    let mut cargo_dir = None;

    while let Some(dir) = search_dir {
        if dir.join("Cargo.toml").exists() {
            cargo_dir = Some(dir.to_path_buf());
            break;
        }
        search_dir = dir.parent();
    }

    let cargo_dir = match cargo_dir {
        Some(c) => c,
        None => return HookResult::ok(),
    };

    if let Some(output) = run_cmd(
        "cargo",
        &["clippy", "--message-format=short"],
        Some(&cargo_dir),
    ) {
        let stderr = String::from_utf8_lossy(&output.stderr);
        let errors: Vec<&str> = stderr
            .lines()
            .filter(|l| l.starts_with("error"))
            .take(10)
            .collect();

        if !errors.is_empty() {
            return HookResult::block(format!("Clippy errors:\n{}", errors.join("\n")));
        }
    }

    HookResult::ok()
}

fn jax_shape_check(input: &HookInput) -> HookResult {
    let file_path = match input.tool_input.as_ref().and_then(|t| t.file_path.as_ref()) {
        Some(p) if p.ends_with(".py") => p,
        _ => return HookResult::ok(),
    };

    if !Path::new(file_path).exists() {
        return HookResult::ok();
    }

    let content = match fs::read_to_string(file_path) {
        Ok(c) => c,
        Err(_) => return HookResult::ok(),
    };

    // Quick check if file uses JAX (fast string check before regex)
    if !content.contains("jax") && !content.contains("flax") && !content.contains("jaxtyping") {
        return HookResult::ok();
    }

    let mut warnings = Vec::new();

    // Check einsum patterns using pre-compiled regex
    for (i, line) in content.lines().enumerate() {
        if let Some(caps) = patterns::EINSUM.captures(line) {
            let subscripts = &caps[1];
            if let Some((inputs, output)) = subscripts.split_once("->") {
                let input_indices: std::collections::HashSet<char> =
                    inputs.chars().filter(|c| c.is_alphabetic()).collect();
                let output_indices: std::collections::HashSet<char> =
                    output.chars().filter(|c| c.is_alphabetic()).collect();
                let invalid: Vec<char> =
                    output_indices.difference(&input_indices).copied().collect();
                if !invalid.is_empty() {
                    warnings.push(format!(
                        "Line {}: einsum output has indices {:?} not present in input",
                        i + 1,
                        invalid
                    ));
                }
            }
        }

        // Check vmap without explicit axes
        if patterns::VMAP.is_match(line) && !line.contains("in_axes") && !line.contains("out_axes")
        {
            warnings.push(format!(
                "Line {}: vmap/pmap without explicit in_axes/out_axes (defaults to 0, verify this is intended)",
                i + 1
            ));
        }
    }

    if !warnings.is_empty() {
        return HookResult::warn(format!(
            "JAX shape/type warnings:\n  {}",
            warnings.join("\n  ")
        ));
    }

    HookResult::ok()
}

fn import_cycle_check(input: &HookInput) -> HookResult {
    let file_path = match input.tool_input.as_ref().and_then(|t| t.file_path.as_ref()) {
        Some(p) if p.ends_with(".py") => p,
        _ => return HookResult::ok(),
    };

    let path = Path::new(file_path);
    let project_root = match find_project_root(path) {
        Some(r) => r,
        None => return HookResult::ok(),
    };

    if project_root.join(".importlinter").exists() {
        if let Some(output) = run_cmd("lint-imports", &[], Some(&project_root)) {
            if !output.status.success() {
                let stderr = String::from_utf8_lossy(&output.stderr);
                return HookResult::warn(format!(
                    "WARNING: Import cycle detected:\n{}",
                    stderr.lines().take(20).collect::<Vec<_>>().join("\n")
                ));
            }
        }
    }

    HookResult::ok()
}

fn session_logger(input: &HookInput) -> HookResult {
    let home = match env::var("HOME") {
        Ok(h) => h,
        Err(_) => return HookResult::ok(),
    };

    let log_dir = PathBuf::from(&home).join(".claude/logs");
    let _ = fs::create_dir_all(&log_dir);

    let now = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .unwrap()
        .as_secs();

    let date = format_date(now);
    let datetime = format_datetime(now);
    let log_file = log_dir.join(format!("session-{}.log", date));

    let session_id = input.session_id.as_deref().unwrap_or("unknown");
    let tool_name = input.tool_name.as_deref().unwrap_or("unknown");

    let detail = match tool_name {
        "Edit" | "Write" | "Read" => {
            let path = input
                .tool_input
                .as_ref()
                .and_then(|t| t.file_path.as_ref())
                .map(|s| s.as_str())
                .unwrap_or("unknown");
            format!("file={}", path)
        }
        "Bash" => {
            let cmd = input
                .tool_input
                .as_ref()
                .and_then(|t| t.command.as_ref())
                .map(|s| if s.len() > 100 { &s[..100] } else { s })
                .unwrap_or("unknown");
            format!("cmd={}", cmd)
        }
        "Glob" | "Grep" => {
            let pattern = input
                .tool_input
                .as_ref()
                .and_then(|t| t.pattern.as_ref())
                .map(|s| s.as_str())
                .unwrap_or("unknown");
            format!("pattern={}", pattern)
        }
        _ => String::new(),
    };

    let log_line = format!(
        "[{}] session={} tool={} {}\n",
        datetime, session_id, tool_name, detail
    );
    let _ = fs::OpenOptions::new()
        .create(true)
        .append(true)
        .open(&log_file)
        .and_then(|mut f| f.write_all(log_line.as_bytes()));

    HookResult::ok()
}

fn inject_context(input: &HookInput) -> HookResult {
    let prompt = match &input.prompt {
        Some(p) => p.to_lowercase(),
        None => return HookResult::ok(),
    };

    let mut context_parts = Vec::new();

    if contains_any(&prompt, &["deploy", "release", "publish"]) {
        context_parts.push("DEPLOYMENT CHECKLIST:\n- Run full test suite before deploying\n- Check for uncommitted changes (git status)\n- Verify version bump in package.json/pyproject.toml/Cargo.toml\n- Update CHANGELOG.md\n- Create git tag after successful deploy");
    }

    if contains_any(&prompt, &["migration", "database", "schema"]) {
        context_parts.push("DATABASE SAFETY:\n- Always backup before migrations\n- Test migrations on staging first\n- Ensure migrations are reversible when possible\n- Check for long-running locks on production tables");
    }

    if contains_any(&prompt, &["optim", "performance", "slow", "fast"]) {
        context_parts.push("PERFORMANCE CHECKLIST:\n- Profile before optimizing (measure, don't guess)\n- Check algorithmic complexity first\n- Consider caching strategies\n- For JAX: ensure JIT compilation, check for recompilation triggers");
    }

    if contains_any(&prompt, &["auth", "security", "password", "token"]) {
        context_parts.push("SECURITY REMINDER:\n- Never hardcode secrets - use environment variables\n- Validate and sanitize all user inputs\n- Use parameterized queries for database operations");
    }

    if contains_any(&prompt, &["test", "coverage", "pytest"]) {
        context_parts.push("TESTING GUIDELINES:\n- Test behavior, not implementation\n- Include edge cases: empty inputs, null values, boundaries\n- For ML: test with fixed random seeds for reproducibility");
    }

    if contains_any(&prompt, &["train", "model", "jax", "flax"]) {
        context_parts.push("ML TRAINING CHECKLIST:\n- Set random seeds for reproducibility\n- Use gradient clipping (optax.clip_by_global_norm)\n- Monitor for NaN/Inf in gradients\n- Checkpoint frequently with Orbax");
    }

    if contains_any(&prompt, &["refactor", "clean", "restructure"]) {
        context_parts.push("REFACTORING GUIDELINES:\n- Ensure tests pass before and after\n- Make small, incremental changes\n- Avoid mixing refactoring with feature changes\n- Use git commits to checkpoint progress");
    }

    if !context_parts.is_empty() {
        let json = serde_json::json!({ "additionalContext": context_parts.join("\n\n") });
        return HookResult::with_context(json.to_string());
    }

    HookResult::ok()
}

const KNOWN_LIBS: &[&str] = &[
    "jax",
    "flax",
    "optax",
    "orbax",
    "grain",
    "jaxtyping",
    "chex",
    "equinox",
    "pydantic",
    "fastapi",
    "pytest",
    "numpy",
    "pandas",
    "transformers",
    "torch",
    "pytorch",
    "tensorflow",
    "langchain",
    "openai",
    "anthropic",
    "httpx",
    "sqlalchemy",
    "redis",
    "celery",
    "aiohttp",
    "requests",
    "django",
    "flask",
];

fn context7_docs(input: &HookInput) -> HookResult {
    let hook_event = input.hook_event_name.as_deref().unwrap_or("");

    match hook_event {
        "UserPromptSubmit" => {
            let prompt = match &input.prompt {
                Some(p) => p.to_lowercase(),
                None => return HookResult::ok(),
            };

            if prompt.contains("context7") {
                return HookResult::ok();
            }

            let is_doc_question = contains_any(
                &prompt,
                &[
                    "how do i",
                    "how to",
                    "how can i",
                    "documentation",
                    "docs",
                    "api",
                    "examples",
                    "tutorial",
                    "guide",
                    "getting started",
                    "learn",
                    "show me how",
                ],
            );

            for lib in KNOWN_LIBS {
                if prompt.contains(lib) {
                    if is_doc_question {
                        let json = serde_json::json!({
                            "additionalContext": format!("Use Context7 MCP for up-to-date {} docs: resolve-library-id('{}') then get-library-docs()", lib, lib)
                        });
                        return HookResult::with_context(json.to_string());
                    } else if prompt.contains('?') {
                        let json = serde_json::json!({
                            "additionalContext": format!("Consider using Context7 MCP for current {} documentation if needed.", lib)
                        });
                        return HookResult::with_context(json.to_string());
                    }
                }
            }
        }
        "PreToolUse" => {
            match &input.tool_name {
                Some(t) if t == "Edit" || t == "Write" => {}
                _ => return HookResult::ok(),
            }

            match input.tool_input.as_ref().and_then(|t| t.file_path.as_ref()) {
                Some(p) if p.ends_with(".py") => {}
                _ => return HookResult::ok(),
            }

            let content = input
                .tool_input
                .as_ref()
                .and_then(|t| t.content.as_ref().or(t.new_string.as_ref()))
                .map(|s| s.to_lowercase())
                .unwrap_or_default();

            for lib in KNOWN_LIBS {
                if content.contains(lib) && content.contains(&format!("{}.", lib)) {
                    return HookResult::warn(format!(
                        "NOTE: Code uses {} APIs. If unsure about function signatures, verify with Context7 MCP.",
                        lib
                    ));
                }
            }
        }
        _ => {}
    }

    HookResult::ok()
}

fn notify_done(input: &HookInput) -> HookResult {
    let stop_reason = input.stop_hook_reason.as_deref().unwrap_or("completed");

    let message = match stop_reason {
        "user_stop" => "Session stopped by user",
        "end_turn" => "Task completed",
        _ => stop_reason,
    };

    // Try macOS notification
    let _ = run_cmd(
        "osascript",
        &[
            "-e",
            &format!(
                "display notification \"{}\" with title \"Claude Code\"",
                message
            ),
        ],
        None,
    );

    // Try Linux notification
    let _ = run_cmd(
        "notify-send",
        &[
            "Claude Code",
            message,
            "--urgency=normal",
            "--icon=terminal",
        ],
        None,
    );

    HookResult::ok()
}

// Helper functions

#[inline]
fn contains_any(haystack: &str, needles: &[&str]) -> bool {
    needles.iter().any(|n| haystack.contains(n))
}

fn find_git_root(path: &Path) -> Option<PathBuf> {
    let mut current = if path.is_file() { path.parent()? } else { path };
    loop {
        if current.join(".git").exists() {
            return Some(current.to_path_buf());
        }
        current = current.parent()?;
    }
}

fn find_project_root(path: &Path) -> Option<PathBuf> {
    let mut current = if path.is_file() { path.parent()? } else { path };
    loop {
        if current.join("pyproject.toml").exists()
            || current.join("setup.py").exists()
            || current.join("setup.cfg").exists()
        {
            return Some(current.to_path_buf());
        }
        current = current.parent()?;
    }
}

fn format_date(secs: u64) -> String {
    let days = secs / 86400;
    let mut y = 1970u64;
    let mut remaining = days;

    loop {
        let days_in_year = if y % 4 == 0 && (y % 100 != 0 || y % 400 == 0) {
            366
        } else {
            365
        };
        if remaining < days_in_year {
            break;
        }
        remaining -= days_in_year;
        y += 1;
    }

    let leap = y % 4 == 0 && (y % 100 != 0 || y % 400 == 0);
    let months: [u64; 12] = if leap {
        [31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
    } else {
        [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
    };

    let mut m = 1;
    for (i, &d) in months.iter().enumerate() {
        if remaining < d {
            m = i + 1;
            break;
        }
        remaining -= d;
    }

    format!("{:04}-{:02}-{:02}", y, m, remaining + 1)
}

fn format_datetime(secs: u64) -> String {
    let date = format_date(secs);
    let time = secs % 86400;
    format!(
        "{} {:02}:{:02}:{:02}",
        date,
        time / 3600,
        (time % 3600) / 60,
        time % 60
    )
}
