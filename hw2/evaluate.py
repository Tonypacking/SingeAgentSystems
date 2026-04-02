#!/usr/bin/env python3

from __future__ import annotations

import argparse
import csv
import os
import statistics
import subprocess
import sys
import tempfile
import textwrap
import time
from pathlib import Path
import re
import shutil


PROJECT_ROOT = Path(__file__).resolve().parent
DEFAULT_JASON_HOME = Path(os.environ.get("JASON_HOME", "/Users/ampapacek/jason-bin-3"))
JASON_HOME = DEFAULT_JASON_HOME
JASON_JAR = JASON_HOME / "bin" / "jason"
SEARCH_JAR = PROJECT_ROOT / "lib" / "search.jar"
CLASSES_DIR = PROJECT_ROOT / "build" / "classes" / "java" / "main"


def resolve_jason_launcher() -> Path:
    if JASON_JAR.exists():
        return JASON_JAR
    path_jason = shutil.which("jason")
    if path_jason:
        return Path(path_jason)
    raise FileNotFoundError(
        "Could not find the Jason launcher. Set JASON_HOME or make 'jason' available on PATH."
    )


STRATEGIES = {
    "dummy": {
        "team_prefix": "dummy",
        "agents": """
        dummy1 agentArchClass arch.LocalMinerArch;
        dummy2 agentArchClass arch.LocalMinerArch;
        dummy3 agentArchClass arch.LocalMinerArch;
        dummy4 agentArchClass arch.LocalMinerArch;
        dummy5 agentArchClass arch.LocalMinerArch;
        dummy6 agentArchClass arch.LocalMinerArch;
        """,
    },
    "example": {
        "team_prefix": "miner",
        "agents": """
        leader
               beliefBaseClass agent.DiscardBelsBB("my_status","picked","committed_to","cell")
               ;

        miner1
               agentClass agent.SelectEvent
               beliefBaseClass agent.UniqueBelsBB("gsize(_,_,_)","depot(_,_,_)","steps(_,_)","committed_to(_,_,key)")
               agentArchClass arch.LocalMinerArch;
        miner2
               agentClass agent.SelectEvent
               beliefBaseClass agent.UniqueBelsBB("gsize(_,_,_)","depot(_,_,_)","steps(_,_)","committed_to(_,_,key)")
               agentArchClass arch.LocalMinerArch;
        miner3
               agentClass agent.SelectEvent
               beliefBaseClass agent.UniqueBelsBB("gsize(_,_,_)","depot(_,_,_)","steps(_,_)","committed_to(_,_,key)")
               agentArchClass arch.LocalMinerArch;
        miner4
               agentClass agent.SelectEvent
               beliefBaseClass agent.UniqueBelsBB("gsize(_,_,_)","depot(_,_,_)","steps(_,_)","committed_to(_,_,key)")
               agentArchClass arch.LocalMinerArch;
        miner5
               agentClass agent.SelectEvent
               beliefBaseClass agent.UniqueBelsBB("gsize(_,_,_)","depot(_,_,_)","steps(_,_)","committed_to(_,_,key)")
               agentArchClass arch.LocalMinerArch;
        miner6
               agentClass agent.SelectEvent
               beliefBaseClass agent.UniqueBelsBB("gsize(_,_,_)","depot(_,_,_)","steps(_,_)","committed_to(_,_,key)")
               agentArchClass arch.LocalMinerArch;
        """,
    },
    "smart": {
        "team_prefix": "smart",
        "agents": """
        smartleader
               beliefBaseClass agent.DiscardBelsBB("my_status","picked","committed_to","cell")
               ;

        smart1
               agentClass agent.SelectEvent
               beliefBaseClass agent.UniqueBelsBB("gsize(_,_,_)","depot(_,_,_)","steps(_,_)","committed_to(_,_,key)")
               agentArchClass arch.LocalMinerArch;
        smart2
               agentClass agent.SelectEvent
               beliefBaseClass agent.UniqueBelsBB("gsize(_,_,_)","depot(_,_,_)","steps(_,_)","committed_to(_,_,key)")
               agentArchClass arch.LocalMinerArch;
        smart3
               agentClass agent.SelectEvent
               beliefBaseClass agent.UniqueBelsBB("gsize(_,_,_)","depot(_,_,_)","steps(_,_)","committed_to(_,_,key)")
               agentArchClass arch.LocalMinerArch;
        smart4
               agentClass agent.SelectEvent
               beliefBaseClass agent.UniqueBelsBB("gsize(_,_,_)","depot(_,_,_)","steps(_,_)","committed_to(_,_,key)")
               agentArchClass arch.LocalMinerArch;
        smart5
               agentClass agent.SelectEvent
               beliefBaseClass agent.UniqueBelsBB("gsize(_,_,_)","depot(_,_,_)","steps(_,_)","committed_to(_,_,key)")
               agentArchClass arch.LocalMinerArch;
        smart6
               agentClass agent.SelectEvent
               beliefBaseClass agent.UniqueBelsBB("gsize(_,_,_)","depot(_,_,_)","steps(_,_)","committed_to(_,_,key)")
               agentArchClass arch.LocalMinerArch;
        """,
    },
}


def compile_sources() -> None:
    CLASSES_DIR.mkdir(parents=True, exist_ok=True)
    jason_launcher = resolve_jason_launcher()
    java_files = sorted(str(path) for path in PROJECT_ROOT.rglob("*.java"))
    cmd = [
        "javac",
        "-cp",
        f"{jason_launcher}:{SEARCH_JAR}",
        "-d",
        str(CLASSES_DIR),
        *java_files,
    ]
    subprocess.run(cmd, cwd=PROJECT_ROOT, check=True)


FINAL_SCORE_RE = re.compile(r"Red x Blue = (\d+) x (\d+)")
ALL_GOLD_RE = re.compile(r"All golds collected in (\d+) cycles! Result \(red x blue\) = (\d+) x (\d+)")
STDOUT_RESULT_RE = re.compile(r"MATCH_RESULT reason=(\S+) world=(\d+) step=(\d+) red=(\d+) blue=(\d+)")


def write_headless_logging_config(path: Path, match_log: Path) -> None:
    path.write_text(
        textwrap.dedent(
            f"""
            handlers = java.util.logging.FileHandler
            .level = INFO
            java.util.logging.FileHandler.pattern = {match_log}
            java.util.logging.FileHandler.limit = 50000000
            java.util.logging.FileHandler.count = 1
            java.util.logging.FileHandler.formatter = jason.runtime.MASConsoleLogFormatter
            java.level=OFF
            javax.level=OFF
            sun.level=OFF
            """
        ).strip()
        + "\n",
        encoding="utf-8",
    )


def make_mas2j(path: Path, world: int, red: str, blue: str, sleep_ms: int, visualize: bool) -> None:
    red_block = textwrap.indent(textwrap.dedent(STRATEGIES[red]["agents"]).strip(), "        ")
    blue_block = textwrap.indent(textwrap.dedent(STRATEGIES[blue]["agents"]).strip(), "        ")
    asl_path = PROJECT_ROOT / "asl"
    gui = "yes" if visualize else "no"
    content = textwrap.dedent(
        f"""
        MAS miners {{
            environment: env.MiningEnvironment({world}, {sleep_ms}, {gui}, "{STRATEGIES[red]['team_prefix']}", "{STRATEGIES[blue]['team_prefix']}", 1000)

            agents:
        {red_block}

        {blue_block}

            aslSourcePath: "{asl_path}";
        }}
        """
    ).strip() + "\n"
    path.write_text(content, encoding="utf-8")


def parse_result(path: Path) -> dict[str, str]:
    result: dict[str, str] = {}
    for line in path.read_text(encoding="utf-8").splitlines():
        if "=" in line:
            key, value = line.split("=", 1)
            result[key] = value
    return result


def parse_match_log(log_path: Path) -> dict[str, object] | None:
    if not log_path.exists():
        return None
    content = log_path.read_text(encoding="utf-8", errors="replace")
    all_gold_match = ALL_GOLD_RE.search(content)
    if all_gold_match:
        step, red, blue = all_gold_match.groups()
        return {
            "reason": "all_gold",
            "step": int(step),
            "red": int(red),
            "blue": int(blue),
        }
    final_match = FINAL_SCORE_RE.search(content)
    if final_match:
        red, blue = final_match.groups()
        cycle_matches = re.findall(r"Cycle (\d+) finished", content)
        step = int(cycle_matches[-1]) if cycle_matches else 0
        return {
            "reason": "max_steps",
            "step": step,
            "red": int(red),
            "blue": int(blue),
        }
    return None


def parse_stdout_result(stdout_path: Path) -> dict[str, object] | None:
    if not stdout_path.exists():
        return None
    content = stdout_path.read_text(encoding="utf-8", errors="replace")
    match = STDOUT_RESULT_RE.search(content)
    if not match:
        return None
    reason, world, step, red, blue = match.groups()
    return {
        "reason": reason,
        "world": int(world),
        "step": int(step),
        "red": int(red),
        "blue": int(blue),
    }


def run_match(world: int, red: str, blue: str, sleep_ms: int, timeout_s: int, visualize: bool) -> dict[str, object]:
    tmpdir_path = Path(tempfile.mkdtemp(prefix="gold-miners-eval-"))
    mas2j_file = tmpdir_path / f"match-{world}-{red}-vs-{blue}.mas2j"
    log_config = tmpdir_path / "logging.properties"
    stdout_log = tmpdir_path / "stdout.log"
    match_log = tmpdir_path / "match.log"

    make_mas2j(mas2j_file, world, red, blue, sleep_ms, visualize)
    write_headless_logging_config(log_config, match_log)

    step_timeout_ms = 1000 if visualize else 1
    start_delay_ms = 1500 if visualize else 0
    cmd = [
        "java",
        f"-Djava.awt.headless={'false' if visualize else 'true'}",
        f"-Dgoldminers.step.timeout.ms={step_timeout_ms}",
        f"-Dgoldminers.start.delay.ms={start_delay_ms}",
        "-cp",
        f"{resolve_jason_launcher()}:{CLASSES_DIR}:{SEARCH_JAR}:.",
        "tools.HeadlessRunner",
        str(mas2j_file),
        str(log_config),
    ]

    parsed_result: dict[str, object] | None = None
    with stdout_log.open("w", encoding="utf-8") as out:
        proc = subprocess.Popen(cmd, cwd=PROJECT_ROOT, stdout=out, stderr=subprocess.STDOUT)
        deadline = time.time() + timeout_s
        while time.time() < deadline:
            parsed_result = parse_stdout_result(stdout_log) or parse_match_log(match_log)
            if parsed_result is not None:
                break
            if proc.poll() is not None:
                parsed_result = parse_stdout_result(stdout_log) or parse_match_log(match_log)
                break
            time.sleep(0.2)

        if parsed_result is None:
            proc.kill()
            proc.wait(timeout=5)
            raise RuntimeError(f"Match timed out without a final score. See {match_log} and {stdout_log}")

        if proc.poll() is None:
            proc.terminate()
            try:
                proc.wait(timeout=5)
            except subprocess.TimeoutExpired:
                proc.kill()
                proc.wait(timeout=5)
        else:
            proc.wait(timeout=5)

    return {
        "world": world,
        "reason": parsed_result["reason"],
        "step": parsed_result["step"],
        "red_strategy": red,
        "blue_strategy": blue,
        "red": parsed_result["red"],
        "blue": parsed_result["blue"],
        "diff": int(parsed_result["blue"]) - int(parsed_result["red"]),
        "stdout_log": str(stdout_log),
        "match_log": str(match_log),
    }


def summarize(results: list[dict[str, object]]) -> list[str]:
    diffs = [int(row["diff"]) for row in results]
    blue_scores = [int(row["blue"]) for row in results]
    red_scores = [int(row["red"]) for row in results]
    wins = sum(1 for row in results if int(row["blue"]) > int(row["red"]))
    draws = sum(1 for row in results if int(row["blue"]) == int(row["red"]))
    losses = len(results) - wins - draws
    return [
        f"matches={len(results)} wins={wins} draws={draws} losses={losses}",
        "avg_blue={:.2f} avg_red={:.2f} avg_diff={:.2f}".format(
            statistics.mean(blue_scores),
            statistics.mean(red_scores),
            statistics.mean(diffs),
        ),
    ]


def main() -> int:
    parser = argparse.ArgumentParser(description="Evaluate gold miners strategies headlessly.")
    parser.add_argument("--red", choices=sorted(STRATEGIES), default="example")
    parser.add_argument("--blue", choices=sorted(STRATEGIES), default="smart")
    parser.add_argument("--worlds", nargs="+", type=int, default=[11, 12, 13])
    parser.add_argument("--runs", type=int, default=3)
    parser.add_argument("--sleep-ms", type=int, default=0)
    parser.add_argument("--timeout-s", type=int, default=180)
    parser.add_argument("--csv", type=Path, default=PROJECT_ROOT / "evaluation-results.csv")
    parser.add_argument(
        "--visualize",
        action="store_true",
        help="Show the simulator GUI for generated matches. For a useful animation, combine with --runs 1 and a nonzero --sleep-ms.",
    )
    args = parser.parse_args()

    if args.red == args.blue:
        parser.error("red and blue strategies must be different")

    compile_sources()

    rows: list[dict[str, object]] = []
    for world in args.worlds:
        for run in range(1, args.runs + 1):
            print(f"Running world {world}, match {run}/{args.runs}: {args.red} vs {args.blue}", flush=True)
            result = run_match(world, args.red, args.blue, args.sleep_ms, args.timeout_s, args.visualize)
            result["run"] = run
            rows.append(result)
            print(
                f"  result: red={result['red']} blue={result['blue']} diff={result['diff']} reason={result['reason']}",
                flush=True,
            )

    with args.csv.open("w", newline="", encoding="utf-8") as fh:
        writer = csv.DictWriter(
            fh,
            fieldnames=[
                "world",
                "run",
                "reason",
                "step",
                "red_strategy",
                "blue_strategy",
                "red",
                "blue",
                "diff",
                "stdout_log",
                "match_log",
            ],
        )
        writer.writeheader()
        writer.writerows(rows)

    print("")
    for line in summarize(rows):
        print(line)
    print(f"csv={args.csv}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
