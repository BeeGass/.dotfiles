import nvitop
from nvitop import Device, HostProcess
import psutil
import plotext as plt
from collections import deque
import typer
from rich.text import Text
from rich.align import Align
from rich.panel import Panel
from rich.ansi import AnsiDecoder
from textual.app import App, ComposeResult
from textual.widgets import Header, Footer, Static, DataTable, Label
from textual.containers import Container, VerticalScroll, Horizontal, Vertical
from textual.binding import Binding
from textual.reactive import reactive
import signal
import os

# --- History Management ---
class History:
    def __init__(self, max_len=60):
        self.max_len = max_len
        self.cpu = deque([0]*max_len, maxlen=max_len)
        self.ram = deque([0]*max_len, maxlen=max_len)
        self.gpu_util = {}
        self.gpu_mem = {}

    def update_cpu(self, cpu, ram):
        self.cpu.append(cpu)
        self.ram.append(ram)

    def update_gpu(self, index, util, mem):
        if index not in self.gpu_util:
            self.gpu_util[index] = deque([0]*self.max_len, maxlen=self.max_len)
            self.gpu_mem[index] = deque([0]*self.max_len, maxlen=self.max_len)
        self.gpu_util[index].append(util)
        self.gpu_mem[index].append(mem)

history = History()

# --- Rendering Helpers ---
def get_plotext_color(name):
    # Map standard names to bright ANSI codes to match "bold" text in Rich
    mapping = {
        "red": 9,      # Bright Red
        "green": 10,   # Bright Green
        "yellow": 11,  # Bright Yellow
        "blue": 12,    # Bright Blue
        "magenta": 13, # Bright Magenta
        "cyan": 14,    # Bright Cyan
        "white": 15,   # Bright White
        "black": 8     # Bright Black (Gray)
    }
    return mapping.get(name, name)

def render_graph(datasets, width=50, height=15, theme_colors=None):
    if not datasets: return ""
    plt.clear_figure()
    plt.plotsize(width, height)
    plt.theme('clear')
    plt.ylim(0, 100)
    plt.yticks(range(0, 101, 10)) # Ticks every 10
    plt.xfrequency(0)
    plt.grid(False, False)
    plt.frame(True)

    for ds in datasets:
        col = get_plotext_color(ds.get('color', 'white'))
        plt.plot(list(ds['data']), color=col, label=ds.get('label', ''), marker="braille")
    
    return plt.build()

# --- Widgets ---
class GraphWidget(Static):
    def __init__(self, role="cpu", device_idx=None, theme_config=None, **kwargs):
        super().__init__(**kwargs)
        self.role = role
        self.device_idx = device_idx
        self.theme_config = theme_config

    def update_graph(self):
        # Use content_region size if available, else fallback
        width = self.content_region.width or 40
        height = self.content_region.height or 10
        
        # Ensure minimal size for plotext
        width = max(20, width)
        height = max(5, height)
        
        datasets = []
        if self.role == "cpu":
            datasets = [
                {'data': history.cpu, 'label': 'CPU', 'color': self.theme_config['cpu_color']},
                {'data': history.ram, 'label': 'RAM', 'color': self.theme_config['ram_color']}
            ]
        elif self.role == "gpu" and self.device_idx is not None:
            datasets = [
                {'data': history.gpu_util.get(self.device_idx, []), 'label': 'GPU', 'color': self.theme_config['gpu_color']},
                {'data': history.gpu_mem.get(self.device_idx, []), 'label': 'VRAM', 'color': self.theme_config['mem_color']}
            ]
        
        graph_ansi = render_graph(datasets, width=width, height=height)
        self.update(Text.from_ansi(graph_ansi))

class StatsWidget(Static):
    def __init__(self, role="cpu", device=None, theme_config=None, **kwargs):
        super().__init__(**kwargs)
        self.role = role
        self.device = device
        self.theme_config = theme_config

    def update_stats(self):
        if self.role == "cpu":
            cpu = psutil.cpu_percent()
            mem = psutil.virtual_memory()
            history.update_cpu(cpu, mem.percent)
            
            # Colors
            c_col = self.theme_config['cpu_color']
            r_col = self.theme_config['ram_color']
            
            # Contrast check for text
            cpu_style = f"bold {c_col}"
            ram_style = f"bold {r_col}"

            content = (
                f"[{cpu_style}]CPU: {cpu}%[/]\n"
                f"[{ram_style}]RAM: {mem.percent}%[/]\n"
                f"Used: {mem.used / (1024**3):.1f} GB\n"
                f"Tot:  {mem.total / (1024**3):.1f} GB"
            )
            self.update(content)

        elif self.role == "gpu" and self.device:
            util = self.device.gpu_utilization()
            mem_used = self.device.memory_used()
            mem_total = self.device.memory_total()
            mem_pct = (mem_used / mem_total) * 100 if mem_total else 0
            history.update_gpu(self.device.index, util, mem_pct)
            
            temp_c = self.device.temperature()
            temp_f = (temp_c * 9/5) + 32
            try: fan = self.device.fan_speed()
            except: fan = 0
            power = self.device.power_usage()
            limit = self.device.power_limit()

            g_col = self.theme_config['gpu_color']
            m_col = self.theme_config['mem_color']
            
            content = (
                f"[bold]{self.device.name()}[/]\n\n"
                f"[{g_col}]GPU: {util}%[/]\n"
                f"[{m_col}]VRAM: {mem_pct:.1f}%[/]\n"
                f"{int(mem_used/1048576)}/{int(mem_total/1048576)} MiB\n\n"
                f"Temp: {temp_f:.1f}°F\n"
                f"Fan:  {fan}%\n"
                f"Pwr:  {power}/{limit}W"
            )
            self.update(content)

class ProcessTableWidget(DataTable):
    BINDINGS = [("k", "kill_process", "Kill Process")]

    def __init__(self, mode="gpu", devices=None, **kwargs):
        super().__init__(**kwargs)
        self.mode = mode
        self.devices = devices
        self.cursor_type = "row"
        
        if self.mode == "gpu":
            self.add_columns("PID", "User", "GPU", "VRAM", "Command")
        else:
            self.add_columns("PID", "User", "CPU%", "MEM%", "Command")

    def action_kill_process(self):
        row = self.get_row_at(self.cursor_coordinate.row)
        if row:
            pid = int(row[0])
            try:
                os.kill(pid, signal.SIGTERM)
                self.notify(f"Sent SIGTERM to PID {pid}")
            except Exception as e:
                self.notify(f"Failed to kill PID {pid}: {e}", severity="error")

    def refresh_table(self):
        new_rows = []
        
        def get_mem(proc):
            # Safe getter for gpu_memory (could be prop or method)
            val = getattr(proc, 'gpu_memory', 0)
            if callable(val):
                try: val = val()
                except: val = 0
            return val if isinstance(val, (int, float)) else 0

        if self.mode == "gpu":
            for device in self.devices:
                try:
                    # Get processes from device (returns dict {pid: GpuProcess} or list)
                    procs_raw = device.processes()
                    if isinstance(procs_raw, dict):
                        procs = list(procs_raw.values())
                    else:
                        procs = list(procs_raw)
                    
                    # Sort by memory usage
                    procs.sort(key=get_mem, reverse=True)
                    
                    for p in procs:
                        # Prepare fields with defaults
                        pid_str = str(p.pid)
                        vram_val = get_mem(p)
                        vram_str = str(int(vram_val / 1048576)) if vram_val else "?"
                        
                        user_str = "?"
                        cmd_str = "?"
                        
                        try:
                            hp = HostProcess(p.pid)
                            user_str = hp.username()
                            cmd = hp.command()
                            if "python" in cmd: cmd = cmd.split("python")[-1].strip()
                            cmd_str = cmd
                        except (psutil.NoSuchProcess, psutil.AccessDenied):
                            user_str = "(root/sys)"
                            cmd_str = "(hidden)"
                        except Exception as e:
                            cmd_str = f"(err: {str(e)})"
                            
                        new_rows.append((
                            pid_str,
                            user_str,
                            str(device.index),
                            vram_str,
                            cmd_str
                        ))
                except Exception as e:
                    # If device.processes() fails completely
                    new_rows.append(("ERR", "Error", str(device.index), str(e), ""))
                    continue
        else:
            # CPU Mode
            for p in psutil.process_iter(['pid', 'username', 'cpu_percent', 'memory_percent', 'name', 'cmdline']):
                try:
                    # Filter out low usage to keep table clean
                    if p.info['cpu_percent'] > 0.1 or p.info['memory_percent'] > 0.1:
                        cmd = p.info['name']
                        if p.info['cmdline']:
                            cmd = " ".join(p.info['cmdline'])
                            if "python" in cmd: cmd = cmd.split("python")[-1].strip()
                        
                        new_rows.append((
                            str(p.info['pid']),
                            p.info['username'] or "?",
                            f"{p.info['cpu_percent']:.1f}",
                            f"{p.info['memory_percent']:.1f}",
                            cmd
                        ))
                except (psutil.NoSuchProcess, psutil.AccessDenied, psutil.ZombieProcess):
                    continue
            # Sort by CPU usage
            new_rows.sort(key=lambda x: float(x[2]), reverse=True)
            new_rows = new_rows[:30] # Top 30 only

        self.clear()
        for r in new_rows:
            self.add_row(*r)

# --- Main App ---
class ZenNVApp(App):
    CSS = """
    Screen {
        layout: grid;
        grid-size: 1 3;
        /* Auto height for System row, 1fr for GPU, 1fr for Procs */
        grid-rows: 14 1fr 1fr;
        background: #000000;
    }
    
    .box {
        /* Generic box */
        padding: 0 1;
        margin: 0 0 1 0;
    }
    
    #system-container {
        layout: horizontal;
        height: 100%;
        border: round white; /* Unified border for System */
    }
    
    #gpu-scroll {
        layout: vertical;
        margin-bottom: 1;
        /* No border around the scroll area itself */
    }
    
    .device-row {
        layout: horizontal;
        height: 12; /* Unified border per GPU, slightly shorter */
        border: round white; 
        margin-bottom: 1;
    }
    
    #proc-container {
        layout: horizontal;
    }
    
    .proc-box {
        width: 1fr;
        height: 100%;
        border: round white;
        margin-right: 1;
    }
    
    .proc-box:last-of-type {
        margin-right: 0;
    }

    StatsWidget {
        width: 1.2fr;
        height: 100%;
        border: none; /* No separate border */
        margin-right: 1;
    }
    
    GraphWidget {
        width: 2fr;
        height: 100%;
        border: none; /* No separate border */
    }
    
    DataTable {
        background: $surface;
        border: none;
    }
    
    Label.proc-header {
        width: 100%;
        text-align: center;
        color: white;
        padding-bottom: 1;
    }
    """

    def __init__(self, theme_config, interval, **kwargs):
        super().__init__(**kwargs)
        self.theme_config = theme_config
        self.interval = interval
        self.devices = Device.all()

    def compose(self) -> ComposeResult:
        # System Row
        with Container(id="system-container", classes="box"):
            yield StatsWidget(role="cpu", theme_config=self.theme_config)
            yield GraphWidget(role="cpu", theme_config=self.theme_config)

        # GPU Scrollable Area (Explicitly added background class logic via CSS)
        with VerticalScroll(id="gpu-scroll"):
            for i, device in enumerate(self.devices):
                with Container(classes="device-row"):
                    yield StatsWidget(role="gpu", device=device, theme_config=self.theme_config)
                    yield GraphWidget(role="gpu", device_idx=i, theme_config=self.theme_config)

        # Process Tables (Split View)
        with Container(id="proc-container"):
            # CPU Processes
            with Vertical(classes="proc-box"):
                yield Label("[bold]Top System Processes[/]", classes="proc-header")
                yield ProcessTableWidget(mode="cpu", devices=None, id="proc-cpu")
            
            # GPU Processes
            with Vertical(classes="proc-box"):
                yield Label("[bold]Active GPU Processes[/]", classes="proc-header")
                yield ProcessTableWidget(mode="gpu", devices=self.devices, id="proc-gpu")
        
        yield Footer()

    def on_mount(self):
        self.title = f"Zen-NV ({self.theme_config['name']})"
        self.set_interval(self.interval, self.update_ui)
        self.update_ui() # Initial call

    def update_ui(self):
        # Update all Stats and Graphs
        for widget in self.query(StatsWidget):
            widget.update_stats()
        for widget in self.query(GraphWidget):
            widget.update_graph()
        
        # Refresh tables periodically
        self.query_one("#proc-cpu", ProcessTableWidget).refresh_table()
        self.query_one("#proc-gpu", ProcessTableWidget).refresh_table()

# --- Typer Entry ---
app = typer.Typer()

THEME_CONFIGS = {
    "ml": {
        "name": "ML",
        "cpu_color": "blue",     
        "ram_color": "orange",     
        "gpu_color": "green",    
        "mem_color": "magenta"    
    },
    "rich": {
        "name": "Rich",
        "cpu_color": "blue",     # Blue vs Yellow
        "ram_color": "yellow",
        "gpu_color": "magenta",  # Magenta vs Green
        "mem_color": "green"
    },
    "zen": {
        "name": "Zen",
        "cpu_color": "white",    # White
        "ram_color": "black",    # Bright Black (Grey)
        "gpu_color": "white",
        "mem_color": "black"
    }
}

@app.command()
def run(
    theme: str = typer.Option("ml", help="Theme: rich, ml, zen"),
    interval: float = typer.Option(1.0, help="Refresh interval")
):
    if theme not in THEME_CONFIGS:
        print(f"Unknown theme. Using ml.")
        theme = "ml"
    
    config = THEME_CONFIGS[theme]
    app = ZenNVApp(theme_config=config, interval=interval)
    app.run()

if __name__ == "__main__":
    app()