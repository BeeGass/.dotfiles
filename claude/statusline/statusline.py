"""Custom status line for Claude Code with ML-focused metrics.

Inspired by zen-nv, uses nvitop for GPU stats and psutil for system metrics.
"""

from __future__ import annotations

import json
import os
import subprocess
import sys
from datetime import datetime
from pathlib import Path

import psutil
from rich.console import Console
from rich.style import Style
from rich.text import Text

try:
    from nvitop import Device

    HAS_NVITOP = True
except ImportError:
    HAS_NVITOP = False

# Tokyo Night inspired muted palette
COLORS = {
    "blue": "#7aa2f7",
    "green": "#9ece6a",
    "yellow": "#e0af68",
    "red": "#f7768e",
    "magenta": "#bb9af7",
    "cyan": "#7dcfff",
    "orange": "#ff9e64",
    "gray": "#565f89",
    "white": "#c0caf5",
    "dim": "#3b4261",
    "separator": "#545c7e",
}

# Separators (compact)
SEP = "│"  # Main separator between segment groups
SUBSEP = ""  # Sub-separator within segments


def style(color: str, bold: bool = False, dim: bool = False) -> Style:
    """Create a style with the given color from palette."""
    return Style(color=COLORS.get(color, color), bold=bold, dim=dim)


def read_claude_context() -> dict[str, object] | None:
    """Read JSON context from Claude Code via stdin."""
    try:
        return json.load(sys.stdin)  # type: ignore[no-any-return]
    except (json.JSONDecodeError, EOFError, ValueError):
        return None


def hex_to_rgb(hex_color: str) -> tuple[int, int, int]:
    """Convert hex color to RGB tuple."""
    hex_color = hex_color.lstrip("#")
    return tuple(int(hex_color[i : i + 2], 16) for i in (0, 2, 4))


def rgb_to_hex(r: int, g: int, b: int) -> str:
    """Convert RGB tuple to hex color."""
    return f"#{r:02x}{g:02x}{b:02x}"


def lerp_color(color1: str, color2: str, t: float) -> str:
    """Linearly interpolate between two hex colors."""
    r1, g1, b1 = hex_to_rgb(color1)
    r2, g2, b2 = hex_to_rgb(color2)
    r = int(r1 + (r2 - r1) * t)
    g = int(g1 + (g2 - g1) * t)
    b = int(b1 + (b2 - b1) * t)
    return rgb_to_hex(r, g, b)


def gradient_color(pct: float, inverse: bool = False) -> str:
    """
    Get a gradient color based on percentage (0-100).

    Colors transition: green -> yellow -> orange -> red
    If inverse=True, low values are bad (e.g., for disk space).
    """
    if inverse:
        pct = 100 - pct

    pct = max(0, min(100, pct))

    # Define color stops
    green = COLORS["green"]
    yellow = COLORS["yellow"]
    orange = COLORS["orange"]
    red = COLORS["red"]

    if pct <= 25:
        # Green zone - pure green
        return green
    elif pct <= 50:
        # Green to yellow transition
        t = (pct - 25) / 25
        return lerp_color(green, yellow, t)
    elif pct <= 75:
        # Yellow to orange transition
        t = (pct - 50) / 25
        return lerp_color(yellow, orange, t)
    else:
        # Orange to red transition
        t = (pct - 75) / 25
        return lerp_color(orange, red, t)


def temp_gradient_color(temp_c: float) -> str:
    """Get gradient color for temperature (Celsius)."""
    # Map temperature to percentage: 30°C = 0%, 90°C = 100%
    pct = ((temp_c - 30) / 60) * 100
    return gradient_color(pct)


def power_gradient_color(power_pct: float) -> str:
    """Get gradient color for power percentage."""
    return gradient_color(power_pct)


def run_cmd(cmd: list[str], timeout: float = 2) -> str | None:
    """Run a command and return stripped stdout, or None on failure."""
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout)
        if result.returncode == 0:
            return result.stdout.strip()
    except (subprocess.TimeoutExpired, FileNotFoundError, OSError):
        pass
    return None


def add_separator(text: Text) -> None:
    """Add a separator to the text."""
    text.append(SEP, style=style("separator"))


# --- Time Segment ---
def build_time_segment() -> Text:
    """Build time segment with 12-hour format and AM/PM."""
    text = Text()
    now = datetime.now()
    text.append(now.strftime("%I:%M"), style=style("white"))
    text.append(now.strftime("%p").lower(), style=style("cyan", dim=True))
    return text


# --- Directory Segment ---
def build_dir_segment() -> Text:
    """Build directory segment with smart truncation."""
    cwd = Path.cwd()
    home = Path.home()

    try:
        relative = cwd.relative_to(home)
        path_str = f"~/{relative}"
    except ValueError:
        path_str = str(cwd)

    parts = path_str.split("/")
    if len(parts) > 4:
        path_str = "/".join([".."] + parts[-2:])

    text = Text()
    text.append(path_str, style=style("blue"))
    return text


# --- Git Segment ---
def is_git_repo() -> bool:
    return run_cmd(["git", "rev-parse", "--git-dir"]) is not None


def get_git_branch() -> str | None:
    branch = run_cmd(["git", "branch", "--show-current"])
    if branch:
        return branch
    sha = run_cmd(["git", "rev-parse", "--short", "HEAD"])
    return f"@{sha}" if sha else None


def get_git_status() -> dict[str, int]:
    status: dict[str, int] = {"staged": 0, "unstaged": 0, "untracked": 0}
    porcelain = run_cmd(["git", "status", "--porcelain"])
    if not porcelain:
        return status

    for line in porcelain.splitlines():
        if len(line) < 2:
            continue
        idx, wt = line[0], line[1]
        if idx == "?":
            status["untracked"] += 1
        else:
            if idx not in (" ", "?"):
                status["staged"] += 1
            if wt not in (" ", "?"):
                status["unstaged"] += 1
    return status


def get_git_remote_status() -> tuple[int, int]:
    ahead, behind = 0, 0
    if not run_cmd(["git", "rev-parse", "--abbrev-ref", "@{upstream}"]):
        return ahead, behind
    ahead_str = run_cmd(["git", "rev-list", "--count", "@{upstream}..HEAD"])
    behind_str = run_cmd(["git", "rev-list", "--count", "HEAD..@{upstream}"])
    if ahead_str:
        ahead = int(ahead_str)
    if behind_str:
        behind = int(behind_str)
    return ahead, behind


def build_git_segment() -> Text | None:
    if not is_git_repo():
        return None

    branch = get_git_branch()
    if not branch:
        return None

    text = Text()

    # Branch name
    is_detached = branch.startswith("@")
    branch_color = "red" if is_detached else "magenta"
    text.append(branch, style=style(branch_color))

    # Status indicators (ASCII/Unicode)
    status = get_git_status()
    ahead, behind = get_git_remote_status()

    indicators: list[tuple[str, str, str]] = []  # (symbol, value, color)
    if status["staged"] > 0:
        indicators.append(("+", str(status["staged"]), "green"))
    if status["unstaged"] > 0:
        indicators.append(("~", str(status["unstaged"]), "yellow"))
    if status["untracked"] > 0:
        indicators.append(("?", str(status["untracked"]), "red"))
    if ahead > 0:
        indicators.append(("↑", str(ahead), "cyan"))
    if behind > 0:
        indicators.append(("↓", str(behind), "orange"))

    if indicators:
        text.append(" ", style=style("dim"))
        for i, (sym, val, color) in enumerate(indicators):
            if i > 0:
                text.append(" ", style=style("dim"))
            text.append(sym, style=style(color))
            text.append(val, style=style(color, dim=True))

    return text


# --- Project/Language Segment ---
def detect_project_type() -> tuple[str | None, str | None, str | None]:
    cwd = Path.cwd()

    if (
        (cwd / "pyproject.toml").exists()
        or (cwd / "setup.py").exists()
        or (cwd / "requirements.txt").exists()
    ):
        py_ver = run_cmd(["python3", "--version"])
        version = None
        if py_ver:
            parts = py_ver.split()
            if len(parts) >= 2:
                version = ".".join(parts[1].split(".")[:2])
        venv = None
        if os.environ.get("VIRTUAL_ENV"):
            venv = Path(os.environ["VIRTUAL_ENV"]).name
        elif (cwd / ".venv").is_dir():
            venv = ".venv"
        return ("python", version, venv)

    if (cwd / "Cargo.toml").exists():
        rust_ver = run_cmd(["rustc", "--version"])
        version = None
        if rust_ver:
            parts = rust_ver.split()
            if len(parts) >= 2:
                version = ".".join(parts[1].split(".")[:2])
        return ("rust", version, None)

    if (cwd / "package.json").exists():
        node_ver = run_cmd(["node", "--version"])
        version = None
        if node_ver:
            version = node_ver.lstrip("v").rsplit(".", 1)[0]
        if (cwd / "tsconfig.json").exists():
            return ("typescript", version, None)
        return ("javascript", version, None)

    if (cwd / "go.mod").exists():
        go_ver = run_cmd(["go", "version"])
        version = None
        if go_ver:
            parts = go_ver.split()
            if len(parts) >= 3:
                version = parts[2].lstrip("go").rsplit(".", 1)[0]
        return ("go", version, None)

    return (None, None, None)


def build_project_segment() -> Text | None:
    proj_type, version, venv = detect_project_type()
    if not proj_type:
        return None

    icons = {"python": "", "rust": "", "typescript": "", "javascript": "", "go": ""}
    colors = {
        "python": "yellow",
        "rust": "orange",
        "typescript": "cyan",
        "javascript": "yellow",
        "go": "cyan",
    }

    icon = icons.get(proj_type, "")
    color = colors.get(proj_type, "white")

    text = Text()
    text.append(icon, style=style(color))

    if version:
        text.append(" ", style=style("dim"))
        text.append(version, style=style(color, dim=True))

    if venv:
        text.append(" ", style=style("dim"))
        text.append(f"({venv})", style=style("gray"))

    return text


# --- Session Segment (SSH, tmux, container) ---
def build_session_segment() -> Text | None:
    indicators: list[tuple[str, str, str]] = []  # (icon, label, color)

    if os.environ.get("SSH_CLIENT") or os.environ.get("SSH_TTY"):
        indicators.append(("", "ssh", "orange"))

    if os.environ.get("TMUX"):
        indicators.append(("", "tmux", "green"))

    if Path("/.dockerenv").exists() or os.environ.get("container"):
        indicators.append(("", "ctr", "cyan"))

    if not indicators:
        return None

    text = Text()
    for i, (icon, label, color) in enumerate(indicators):
        if i > 0:
            text.append(" ", style=style("dim"))
        text.append(icon, style=style(color))
        text.append(label, style=style(color, dim=True))

    return text


# --- CPU Segment (using psutil) ---
def build_cpu_segment() -> Text | None:
    """Build CPU segment - only show if load is notable (>25%)."""
    cpu_pct = psutil.cpu_percent(interval=None)

    if cpu_pct < 25:
        return None

    color = gradient_color(cpu_pct)

    text = Text()
    text.append("CPU ", style=style("blue"))
    text.append(f"{cpu_pct:.0f}%", style=Style(color=color))
    return text


# --- Memory Segment (using psutil) ---
def build_memory_segment() -> Text | None:
    """Build memory segment - only show if usage is notable (>50%)."""
    mem = psutil.virtual_memory()
    pct = mem.percent

    if pct < 50:
        return None

    used_gb = mem.used / (1024**3)
    total_gb = mem.total / (1024**3)

    color = gradient_color(pct)

    text = Text()
    text.append("RAM ", style=style("blue"))
    text.append(f"{used_gb:.0f}", style=Style(color=color))
    text.append("/", style=style("dim"))
    text.append(f"{total_gb:.0f}G", style=Style(color=color, dim=True))
    return text


# --- GPU Segment (using nvitop) ---
def build_gpu_segment() -> Text | None:
    """Build GPU segment with utilization, memory, temp, and power."""
    if not HAS_NVITOP:
        return None

    try:
        devices = Device.all()
        if not devices:
            return None

        device = devices[0]

        util = device.gpu_utilization() or 0
        mem_used = device.memory_used() or 0
        mem_total = device.memory_total() or 1
        mem_pct = (mem_used / mem_total) * 100 if mem_total else 0

        temp_c = device.temperature() or 0
        power = (device.power_usage() or 0) / 1000
        power_limit = (device.power_limit() or 0) / 1000

        # Gradient colors for each metric
        gpu_color = gradient_color(util)
        vram_color = gradient_color(mem_pct)
        temp_color = temp_gradient_color(temp_c)
        power_pct = (power / power_limit * 100) if power_limit else 0
        pwr_color = power_gradient_color(power_pct)

        mem_used_gb = mem_used / (1024**3)
        mem_total_gb = mem_total / (1024**3)
        temp_f = (temp_c * 9 / 5) + 32

        text = Text()
        # Compact format: GPU 7% 3/32G 118F 50W
        text.append("GPU ", style=style("green"))
        text.append(f"{util}%", style=Style(color=gpu_color))
        text.append(" ", style=style("dim"))
        text.append(f"{mem_used_gb:.0f}", style=Style(color=vram_color))
        text.append("/", style=style("dim"))
        text.append(f"{mem_total_gb:.0f}G", style=Style(color=vram_color, dim=True))
        text.append(" ", style=style("dim"))
        text.append(f"{temp_f:.0f}°F", style=Style(color=temp_color))
        text.append(" ", style=style("dim"))
        text.append(f"{power:.0f}W", style=Style(color=pwr_color))

        return text

    except Exception:
        return None


def build_multi_gpu_segment() -> Text | None:
    """Build segment showing all GPUs in a compact format."""
    if not HAS_NVITOP:
        return None

    try:
        devices = Device.all()
        if not devices:
            return None

        if len(devices) == 1:
            return build_gpu_segment()

        # Multi-GPU: show compact summary for each
        text = Text()
        text.append("GPUs:", style=style("green"))
        text.append(" ", style=style("dim"))

        for i, device in enumerate(devices):
            if i > 0:
                text.append("  ", style=style("dim"))

            util = device.gpu_utilization() or 0
            mem_used = device.memory_used() or 0
            mem_total = device.memory_total() or 1
            mem_pct = (mem_used / mem_total) * 100

            gpu_color = gradient_color(util)
            vram_color = gradient_color(mem_pct)

            mem_gb = mem_used / (1024**3)
            text.append(f"[{i}]", style=style("gray"))
            text.append(f"{util}%", style=Style(color=gpu_color))
            text.append("/", style=style("dim"))
            text.append(f"{mem_gb:.0f}G", style=Style(color=vram_color, dim=True))

        return text

    except Exception:
        return None


# --- Disk Warning ---
def build_disk_warning() -> Text | None:
    """Build disk warning if space is low (<10GB)."""
    try:
        usage = psutil.disk_usage(".")
        free_gb = usage.free / (1024**3)
        if free_gb < 10:
            text = Text()
            text.append("Disk ", style=style("red"))
            text.append(f"{free_gb:.0f}G", style=style("red"))
            return text
    except OSError:
        pass
    return None


# --- Context Window Usage ---
def build_context_segment(ctx: dict[str, object] | None) -> Text | None:
    """Build context window usage segment: CTX 32%"""
    if not ctx:
        return None

    cw = ctx.get("context_window")
    if not isinstance(cw, dict):
        return None

    cw_size = cw.get("context_window_size")
    if not isinstance(cw_size, int) or cw_size == 0:
        return None

    usage = cw.get("current_usage")
    if not isinstance(usage, dict):
        return None

    input_tokens = usage.get("input_tokens", 0)
    output_tokens = usage.get("output_tokens", 0)
    cache_tokens = usage.get("cache_creation_input_tokens", 0)

    if not all(isinstance(t, int) for t in (input_tokens, output_tokens, cache_tokens)):
        return None

    total_tokens = input_tokens + output_tokens + cache_tokens
    pct = (total_tokens / cw_size) * 100

    text = Text()
    text.append("CTX ", style=style("blue"))
    text.append(f"{pct:.0f}%", style=Style(color=gradient_color(pct)))
    return text


# --- Main ---
def main() -> None:
    """Build and print the complete statusline (single line when possible)."""
    console = Console(force_terminal=True, color_system="truecolor")

    # Read context from Claude Code
    ctx = read_claude_context()

    line = Text()

    # Context: time, directory, git
    line.append_text(build_time_segment())
    add_separator(line)
    line.append_text(build_dir_segment())

    if git_seg := build_git_segment():
        add_separator(line)
        line.append_text(git_seg)

    # Project and session
    proj_seg = build_project_segment()
    session_seg = build_session_segment()

    if proj_seg or session_seg:
        add_separator(line)
        if proj_seg:
            line.append_text(proj_seg)
        if session_seg:
            if proj_seg:
                line.append(" ", style=style("dim"))
            line.append_text(session_seg)

    # System resources
    cpu_seg = build_cpu_segment()
    mem_seg = build_memory_segment()
    gpu_seg = build_multi_gpu_segment()
    disk_seg = build_disk_warning()

    resource_parts = []
    if cpu_seg:
        resource_parts.append(cpu_seg)
    if mem_seg:
        resource_parts.append(mem_seg)
    if gpu_seg:
        resource_parts.append(gpu_seg)
    if disk_seg:
        resource_parts.append(disk_seg)

    if resource_parts:
        add_separator(line)
        for i, part in enumerate(resource_parts):
            if i > 0:
                line.append(" ", style=style("dim"))
            line.append_text(part)

    # Context window usage
    if ctx_seg := build_context_segment(ctx):
        add_separator(line)
        line.append_text(ctx_seg)

    console.print(line, end="")


if __name__ == "__main__":
    main()
