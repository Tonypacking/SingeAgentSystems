#!/usr/bin/env python3
"""
evaluate_all.py — Run ALL strategy combinations and build a leaderboard.

Tests every ordered pair (red, blue) of strategies across multiple worlds
and runs. Results are saved to a timestamped session directory under hw2/results/.

Output per session:
  results/<timestamp>/
    matches.csv       — one row per individual match
    summary.csv       — per-strategy aggregate stats
    head_to_head.csv  — win/draw/loss matrix between every pair
    session.log       — full console output

Usage examples:
  python evaluate_all.py                          # all vs all, defaults
  python evaluate_all.py --worlds 11 12 13 --runs 3
  python evaluate_all.py --strategies dummy smart  # only those two
  python evaluate_all.py --timeout-s 240
"""

from __future__ import annotations

import argparse
import csv
import itertools
import os
import re
import shutil
import statistics
import subprocess
import sys
import tempfile
import textwrap
import time
from datetime import datetime
from pathlib import Path

# ── Paths ─────────────────────────────────────────────────────────────────────

PROJECT_ROOT  = Path(__file__).resolve().parent
JASON_HOME    = Path(os.environ.get("JASON_HOME", "/Users/ampapacek/jason-bin-3"))
JASON_JAR     = JASON_HOME / "bin" / "jason"
SEARCH_JAR    = PROJECT_ROOT / "lib" / "search.jar"
CLASSES_DIR   = PROJECT_ROOT / "build" / "classes" / "java" / "main"
RESULTS_ROOT  = PROJECT_ROOT / "results"

# ── Strategy definitions ───────────────────────────────────────────────────────

STRATEGIES: dict[str, dict] = {
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
    "titan": {
        "team_prefix": "titan",
        "agents": """
        titan1 titan.asl
               agentClass agent.SelectEvent
               beliefBaseClass agent.UniqueBelsBB("gsize(_,_,_)","depot(_,_,_)","steps(_,_)","committed_to(_,_,key)")
               agentArchClass arch.LocalMinerArch;
        titan2 titan.asl
               agentClass agent.SelectEvent
               beliefBaseClass agent.UniqueBelsBB("gsize(_,_,_)","depot(_,_,_)","steps(_,_)","committed_to(_,_,key)")
               agentArchClass arch.LocalMinerArch;
        titan3 titan.asl
               agentClass agent.SelectEvent
               beliefBaseClass agent.UniqueBelsBB("gsize(_,_,_)","depot(_,_,_)","steps(_,_)","committed_to(_,_,key)")
               agentArchClass arch.LocalMinerArch;
        titan4 titan.asl
               agentClass agent.SelectEvent
               beliefBaseClass agent.UniqueBelsBB("gsize(_,_,_)","depot(_,_,_)","steps(_,_)","committed_to(_,_,key)")
               agentArchClass arch.LocalMinerArch;
        titan5 titan.asl
               agentClass agent.SelectEvent
               beliefBaseClass agent.UniqueBelsBB("gsize(_,_,_)","depot(_,_,_)","steps(_,_)","committed_to(_,_,key)")
               agentArchClass arch.LocalMinerArch;
        titan6 titan.asl
               agentClass agent.SelectEvent
               beliefBaseClass agent.UniqueBelsBB("gsize(_,_,_)","depot(_,_,_)","steps(_,_)","committed_to(_,_,key)")
               agentArchClass arch.LocalMinerArch;
        """,
    },
    "apex": {
        "team_prefix": "apex",
        "agents": """
        apex1 apex.asl
               agentClass agent.SelectEvent
               beliefBaseClass agent.UniqueBelsBB("gsize(_,_,_)","depot(_,_,_)","steps(_,_)","committed_to(_,_,key)")
               agentArchClass arch.LocalMinerArch;
        apex2 apex.asl
               agentClass agent.SelectEvent
               beliefBaseClass agent.UniqueBelsBB("gsize(_,_,_)","depot(_,_,_)","steps(_,_)","committed_to(_,_,key)")
               agentArchClass arch.LocalMinerArch;
        apex3 apex.asl
               agentClass agent.SelectEvent
               beliefBaseClass agent.UniqueBelsBB("gsize(_,_,_)","depot(_,_,_)","steps(_,_)","committed_to(_,_,key)")
               agentArchClass arch.LocalMinerArch;
        apex4 apex.asl
               agentClass agent.SelectEvent
               beliefBaseClass agent.UniqueBelsBB("gsize(_,_,_)","depot(_,_,_)","steps(_,_)","committed_to(_,_,key)")
               agentArchClass arch.LocalMinerArch;
        apex5 apex.asl
               agentClass agent.SelectEvent
               beliefBaseClass agent.UniqueBelsBB("gsize(_,_,_)","depot(_,_,_)","steps(_,_)","committed_to(_,_,key)")
               agentArchClass arch.LocalMinerArch;
        apex6 apex.asl
               agentClass agent.SelectEvent
               beliefBaseClass agent.UniqueBelsBB("gsize(_,_,_)","depot(_,_,_)","steps(_,_)","committed_to(_,_,key)")
               agentArchClass arch.LocalMinerArch;
        """,
    },
    "apex_prime": {
        "team_prefix": "prime",
        "agents": """
        apex_leader apex_leader.asl
               beliefBaseClass agent.DiscardBelsBB("my_status","picked","committed_to","cell")
               ;

        prime1 apex_prime.asl
               agentClass agent.SelectEvent
               beliefBaseClass agent.UniqueBelsBB("gsize(_,_,_)","depot(_,_,_)","steps(_,_)","committed_to(_,_,key)")
               agentArchClass arch.LocalMinerArch;
        prime2 apex_prime.asl
               agentClass agent.SelectEvent
               beliefBaseClass agent.UniqueBelsBB("gsize(_,_,_)","depot(_,_,_)","steps(_,_)","committed_to(_,_,key)")
               agentArchClass arch.LocalMinerArch;
        prime3 apex_prime.asl
               agentClass agent.SelectEvent
               beliefBaseClass agent.UniqueBelsBB("gsize(_,_,_)","depot(_,_,_)","steps(_,_)","committed_to(_,_,key)")
               agentArchClass arch.LocalMinerArch;
        prime4 apex_prime.asl
               agentClass agent.SelectEvent
               beliefBaseClass agent.UniqueBelsBB("gsize(_,_,_)","depot(_,_,_)","steps(_,_)","committed_to(_,_,key)")
               agentArchClass arch.LocalMinerArch;
        prime5 apex_prime.asl
               agentClass agent.SelectEvent
               beliefBaseClass agent.UniqueBelsBB("gsize(_,_,_)","depot(_,_,_)","steps(_,_)","committed_to(_,_,key)")
               agentArchClass arch.LocalMinerArch;
        prime6 apex_prime.asl
               agentClass agent.SelectEvent
               beliefBaseClass agent.UniqueBelsBB("gsize(_,_,_)","depot(_,_,_)","steps(_,_)","committed_to(_,_,key)")
               agentArchClass arch.LocalMinerArch;
        """,
    },
    # "omega": {
        # "team_prefix": "omega",
        # "agents": """
        # omega1 omega.asl
               # agentClass agent.SelectEvent
               # beliefBaseClass agent.UniqueBelsBB("gsize(_,_,_)","depot(_,_,_)","steps(_,_)","committed_to(_,_,key)")
               # agentArchClass arch.LocalMinerArch;
        # omega2 omega.asl
               # agentClass agent.SelectEvent
               # beliefBaseClass agent.UniqueBelsBB("gsize(_,_,_)","depot(_,_,_)","steps(_,_)","committed_to(_,_,key)")
               # agentArchClass arch.LocalMinerArch;
        # omega3 omega.asl
               # agentClass agent.SelectEvent
               # beliefBaseClass agent.UniqueBelsBB("gsize(_,_,_)","depot(_,_,_)","steps(_,_)","committed_to(_,_,key)")
               # agentArchClass arch.LocalMinerArch;
        # omega4 omega.asl
               # agentClass agent.SelectEvent
               # beliefBaseClass agent.UniqueBelsBB("gsize(_,_,_)","depot(_,_,_)","steps(_,_)","committed_to(_,_,key)")
               # agentArchClass arch.LocalMinerArch;
        # omega5 omega.asl
               # agentClass agent.SelectEvent
               # beliefBaseClass agent.UniqueBelsBB("gsize(_,_,_)","depot(_,_,_)","steps(_,_)","committed_to(_,_,key)")
               # agentArchClass arch.LocalMinerArch;
        # omega6 omega.asl
               # agentClass agent.SelectEvent
               # beliefBaseClass agent.UniqueBelsBB("gsize(_,_,_)","depot(_,_,_)","steps(_,_)","committed_to(_,_,key)")
               # agentArchClass arch.LocalMinerArch;
        # """,
    # },
    # "example": {
        # "team_prefix": "miner",
        # "agents": """
        # leader
               # beliefBaseClass agent.DiscardBelsBB("my_status","picked","committed_to","cell")
               # ;

        # miner1
               # agentClass agent.SelectEvent
               # beliefBaseClass agent.UniqueBelsBB("gsize(_,_,_)","depot(_,_,_)","steps(_,_)","committed_to(_,_,key)")
               # agentArchClass arch.LocalMinerArch;
        # miner2
               # agentClass agent.SelectEvent
               # beliefBaseClass agent.UniqueBelsBB("gsize(_,_,_)","depot(_,_,_)","steps(_,_)","committed_to(_,_,key)")
               # agentArchClass arch.LocalMinerArch;
        # miner3
               # agentClass agent.SelectEvent
               # beliefBaseClass agent.UniqueBelsBB("gsize(_,_,_)","depot(_,_,_)","steps(_,_)","committed_to(_,_,key)")
               # agentArchClass arch.LocalMinerArch;
        # miner4
               # agentClass agent.SelectEvent
               # beliefBaseClass agent.UniqueBelsBB("gsize(_,_,_)","depot(_,_,_)","steps(_,_)","committed_to(_,_,key)")
               # agentArchClass arch.LocalMinerArch;
        # miner5
               # agentClass agent.SelectEvent
               # beliefBaseClass agent.UniqueBelsBB("gsize(_,_,_)","depot(_,_,_)","steps(_,_)","committed_to(_,_,key)")
               # agentArchClass arch.LocalMinerArch;
        # miner6
               # agentClass agent.SelectEvent
               # beliefBaseClass agent.UniqueBelsBB("gsize(_,_,_)","depot(_,_,_)","steps(_,_)","committed_to(_,_,key)")
               # agentArchClass arch.LocalMinerArch;
        # """,
    # },
    # "smart": {
        # "team_prefix": "smart",
        # "agents": """
        # smartleader
               # beliefBaseClass agent.DiscardBelsBB("my_status","picked","committed_to","cell")
               # ;

        # smart1
               # agentClass agent.SelectEvent
               # beliefBaseClass agent.UniqueBelsBB("gsize(_,_,_)","depot(_,_,_)","steps(_,_)","committed_to(_,_,key)")
               # agentArchClass arch.LocalMinerArch;
        # smart2
               # agentClass agent.SelectEvent
               # beliefBaseClass agent.UniqueBelsBB("gsize(_,_,_)","depot(_,_,_)","steps(_,_)","committed_to(_,_,key)")
               # agentArchClass arch.LocalMinerArch;
        # smart3
               # agentClass agent.SelectEvent
               # beliefBaseClass agent.UniqueBelsBB("gsize(_,_,_)","depot(_,_,_)","steps(_,_)","committed_to(_,_,key)")
               # agentArchClass arch.LocalMinerArch;
        # smart4
               # agentClass agent.SelectEvent
               # beliefBaseClass agent.UniqueBelsBB("gsize(_,_,_)","depot(_,_,_)","steps(_,_)","committed_to(_,_,key)")
               # agentArchClass arch.LocalMinerArch;
        # smart5
               # agentClass agent.SelectEvent
               # beliefBaseClass agent.UniqueBelsBB("gsize(_,_,_)","depot(_,_,_)","steps(_,_)","committed_to(_,_,key)")
               # agentArchClass arch.LocalMinerArch;
        # smart6
               # agentClass agent.SelectEvent
               # beliefBaseClass agent.UniqueBelsBB("gsize(_,_,_)","depot(_,_,_)","steps(_,_)","committed_to(_,_,key)")
               # agentArchClass arch.LocalMinerArch;
        # """,
    # },
    # "giga": {
        # "team_prefix": "giga",
        # "agents": """
        # giga1 giga.asl
               # agentClass agent.SelectEvent
               # beliefBaseClass agent.UniqueBelsBB("gsize(_,_,_)","depot(_,_,_)","steps(_,_)","committed_to(_,_,key)")
               # agentArchClass arch.LocalMinerArch;
        # giga2 giga.asl
               # agentClass agent.SelectEvent
               # beliefBaseClass agent.UniqueBelsBB("gsize(_,_,_)","depot(_,_,_)","steps(_,_)","committed_to(_,_,key)")
               # agentArchClass arch.LocalMinerArch;
        # giga3 giga.asl
               # agentClass agent.SelectEvent
               # beliefBaseClass agent.UniqueBelsBB("gsize(_,_,_)","depot(_,_,_)","steps(_,_)","committed_to(_,_,key)")
               # agentArchClass arch.LocalMinerArch;
        # giga4 giga.asl
               # agentClass agent.SelectEvent
               # beliefBaseClass agent.UniqueBelsBB("gsize(_,_,_)","depot(_,_,_)","steps(_,_)","committed_to(_,_,key)")
               # agentArchClass arch.LocalMinerArch;
        # giga5 giga.asl
               # agentClass agent.SelectEvent
               # beliefBaseClass agent.UniqueBelsBB("gsize(_,_,_)","depot(_,_,_)","steps(_,_)","committed_to(_,_,key)")
               # agentArchClass arch.LocalMinerArch;
        # giga6 giga.asl
               # agentClass agent.SelectEvent
               # beliefBaseClass agent.UniqueBelsBB("gsize(_,_,_)","depot(_,_,_)","steps(_,_)","committed_to(_,_,key)")
               # agentArchClass arch.LocalMinerArch;
        # """,
    # },
    # "mystrategy": {
        # "team_prefix": "my",
        # "agents": """
        # mystrategy1 mystrategy.asl
               # agentClass agent.SelectEvent
               # beliefBaseClass agent.UniqueBelsBB("gsize(_,_,_)","depot(_,_,_)","steps(_,_)","committed_to(_,_,key)")
               # agentArchClass arch.LocalMinerArch;
        # mystrategy2 mystrategy.asl
               # agentClass agent.SelectEvent
               # beliefBaseClass agent.UniqueBelsBB("gsize(_,_,_)","depot(_,_,_)","steps(_,_)","committed_to(_,_,key)")
               # agentArchClass arch.LocalMinerArch;
        # mystrategy3 mystrategy.asl
               # agentClass agent.SelectEvent
               # beliefBaseClass agent.UniqueBelsBB("gsize(_,_,_)","depot(_,_,_)","steps(_,_)","committed_to(_,_,key)")
               # agentArchClass arch.LocalMinerArch;
        # mystrategy4 mystrategy.asl
               # agentClass agent.SelectEvent
               # beliefBaseClass agent.UniqueBelsBB("gsize(_,_,_)","depot(_,_,_)","steps(_,_)","committed_to(_,_,key)")
               # agentArchClass arch.LocalMinerArch;
        # mystrategy5 mystrategy.asl
               # agentClass agent.SelectEvent
               # beliefBaseClass agent.UniqueBelsBB("gsize(_,_,_)","depot(_,_,_)","steps(_,_)","committed_to(_,_,key)")
               # agentArchClass arch.LocalMinerArch;
        # mystrategy6 mystrategy.asl
               # agentClass agent.SelectEvent
               # beliefBaseClass agent.UniqueBelsBB("gsize(_,_,_)","depot(_,_,_)","steps(_,_)","committed_to(_,_,key)")
               # agentArchClass arch.LocalMinerArch;
        # """,
    # },
    # "sigma": {
        # "team_prefix": "sigma",
        # "agents": """
        # sigma1 sigma.asl
               # agentClass agent.SelectEvent
               # beliefBaseClass agent.UniqueBelsBB("gsize(_,_,_)","depot(_,_,_)","steps(_,_)","committed_to(_,_,key)")
               # agentArchClass arch.LocalMinerArch;
        # sigma2 sigma.asl
               # agentClass agent.SelectEvent
               # beliefBaseClass agent.UniqueBelsBB("gsize(_,_,_)","depot(_,_,_)","steps(_,_)","committed_to(_,_,key)")
               # agentArchClass arch.LocalMinerArch;
        # sigma3 sigma.asl
               # agentClass agent.SelectEvent
               # beliefBaseClass agent.UniqueBelsBB("gsize(_,_,_)","depot(_,_,_)","steps(_,_)","committed_to(_,_,key)")
               # agentArchClass arch.LocalMinerArch;
        # sigma4 sigma.asl
               # agentClass agent.SelectEvent
               # beliefBaseClass agent.UniqueBelsBB("gsize(_,_,_)","depot(_,_,_)","steps(_,_)","committed_to(_,_,key)")
               # agentArchClass arch.LocalMinerArch;
        # sigma5 sigma.asl
               # agentClass agent.SelectEvent
               # beliefBaseClass agent.UniqueBelsBB("gsize(_,_,_)","depot(_,_,_)","steps(_,_)","committed_to(_,_,key)")
               # agentArchClass arch.LocalMinerArch;
        # sigma6 sigma.asl
               # agentClass agent.SelectEvent
               # beliefBaseClass agent.UniqueBelsBB("gsize(_,_,_)","depot(_,_,_)","steps(_,_)","committed_to(_,_,key)")
               # agentArchClass arch.LocalMinerArch;
        # """,
    # },
    # "adv": {
        # "team_prefix": "adv",
        # "agents": """
        # advleader
               # beliefBaseClass agent.DiscardBelsBB("my_status","committed_to","cell")
               # ;

        # adv1
               # agentClass agent.SelectEvent
               # beliefBaseClass agent.UniqueBelsBB("gsize(_,_,_)","depot(_,_,_)","steps(_,_)","committed_to(_,_,key)")
               # agentArchClass arch.LocalMinerArch;
        # adv2
               # agentClass agent.SelectEvent
               # beliefBaseClass agent.UniqueBelsBB("gsize(_,_,_)","depot(_,_,_)","steps(_,_)","committed_to(_,_,key)")
               # agentArchClass arch.LocalMinerArch;
        # adv3
               # agentClass agent.SelectEvent
               # beliefBaseClass agent.UniqueBelsBB("gsize(_,_,_)","depot(_,_,_)","steps(_,_)","committed_to(_,_,key)")
               # agentArchClass arch.LocalMinerArch;
        # adv4
               # agentClass agent.SelectEvent
               # beliefBaseClass agent.UniqueBelsBB("gsize(_,_,_)","depot(_,_,_)","steps(_,_)","committed_to(_,_,key)")
               # agentArchClass arch.LocalMinerArch;
        # adv5
               # agentClass agent.SelectEvent
               # beliefBaseClass agent.UniqueBelsBB("gsize(_,_,_)","depot(_,_,_)","steps(_,_)","committed_to(_,_,key)")
               # agentArchClass arch.LocalMinerArch;
        # adv6
               # agentClass agent.SelectEvent
               # beliefBaseClass agent.UniqueBelsBB("gsize(_,_,_)","depot(_,_,_)","steps(_,_)","committed_to(_,_,key)")
               # agentArchClass arch.LocalMinerArch;
        # """,
    # },
    # "q6quadrant": {
        # "team_prefix": "q6",
        # "agents": """
        # q6leader
               # beliefBaseClass agent.DiscardBelsBB("my_status","committed_to","cell")
               # ;

        # q6m1
               # agentClass agent.SelectEvent
               # beliefBaseClass agent.UniqueBelsBB("gsize(_,_,_)","depot(_,_,_)","steps(_,_)","committed_to(_,_,key)")
               # agentArchClass arch.LocalMinerArch;
        # q6m2
               # agentClass agent.SelectEvent
               # beliefBaseClass agent.UniqueBelsBB("gsize(_,_,_)","depot(_,_,_)","steps(_,_)","committed_to(_,_,key)")
               # agentArchClass arch.LocalMinerArch;
        # q6m3
               # agentClass agent.SelectEvent
               # beliefBaseClass agent.UniqueBelsBB("gsize(_,_,_)","depot(_,_,_)","steps(_,_)","committed_to(_,_,key)")
               # agentArchClass arch.LocalMinerArch;
        # q6m4
               # agentClass agent.SelectEvent
               # beliefBaseClass agent.UniqueBelsBB("gsize(_,_,_)","depot(_,_,_)","steps(_,_)","committed_to(_,_,key)")
               # agentArchClass arch.LocalMinerArch;
        # q6m5
               # agentClass agent.SelectEvent
               # beliefBaseClass agent.UniqueBelsBB("gsize(_,_,_)","depot(_,_,_)","steps(_,_)","committed_to(_,_,key)")
               # agentArchClass arch.LocalMinerArch;
        # q6m6
               # agentClass agent.SelectEvent
               # beliefBaseClass agent.UniqueBelsBB("gsize(_,_,_)","depot(_,_,_)","steps(_,_)","committed_to(_,_,key)")
               # agentArchClass arch.LocalMinerArch;
        # """,
    # },
    # "skibidy": {
        # "team_prefix": "skibidy",
        # "agents": """
        # skibidyleader skibidyleader.asl
               # beliefBaseClass agent.DiscardBelsBB("my_status","picked","committed_to","cell")
               # ;

        # skibidyminer1 skibidyminer.asl
               # agentClass agent.SelectEvent
               # beliefBaseClass agent.UniqueBelsBB("gsize(_,_,_)","depot(_,_,_)","steps(_,_)","committed_to(_,_,key)")
               # agentArchClass arch.LocalMinerArch;
        # skibidyminer2 skibidyminer.asl
               # agentClass agent.SelectEvent
               # beliefBaseClass agent.UniqueBelsBB("gsize(_,_,_)","depot(_,_,_)","steps(_,_)","committed_to(_,_,key)")
               # agentArchClass arch.LocalMinerArch;
        # skibidyminer3 skibidyminer.asl
               # agentClass agent.SelectEvent
               # beliefBaseClass agent.UniqueBelsBB("gsize(_,_,_)","depot(_,_,_)","steps(_,_)","committed_to(_,_,key)")
               # agentArchClass arch.LocalMinerArch;
        # skibidyminer4 skibidyminer.asl
               # agentClass agent.SelectEvent
               # beliefBaseClass agent.UniqueBelsBB("gsize(_,_,_)","depot(_,_,_)","steps(_,_)","committed_to(_,_,key)")
               # agentArchClass arch.LocalMinerArch;
        # skibidyminer5 skibidyminer.asl
               # agentClass agent.SelectEvent
               # beliefBaseClass agent.UniqueBelsBB("gsize(_,_,_)","depot(_,_,_)","steps(_,_)","committed_to(_,_,key)")
               # agentArchClass arch.LocalMinerArch;
        # skibidyminer6 skibidyminer.asl
               # agentClass agent.SelectEvent
               # beliefBaseClass agent.UniqueBelsBB("gsize(_,_,_)","depot(_,_,_)","steps(_,_)","committed_to(_,_,key)")
               # agentArchClass arch.LocalMinerArch;
        # """,
    # },
    "toilet": {
        "team_prefix": "toilet",
        "agents": """
        toiletleader toiletleader.asl
               beliefBaseClass agent.DiscardBelsBB("my_status","picked","committed_to","cell")
               ;

        toilet1 toiletminer.asl
               agentClass agent.SelectEvent
               beliefBaseClass agent.UniqueBelsBB("gsize(_,_,_)","depot(_,_,_)","steps(_,_)","committed_to(_,_,key)")
               agentArchClass arch.LocalMinerArch;
        toilet2 toiletminer.asl
               agentClass agent.SelectEvent
               beliefBaseClass agent.UniqueBelsBB("gsize(_,_,_)","depot(_,_,_)","steps(_,_)","committed_to(_,_,key)")
               agentArchClass arch.LocalMinerArch;
        toilet3 toiletminer.asl
               agentClass agent.SelectEvent
               beliefBaseClass agent.UniqueBelsBB("gsize(_,_,_)","depot(_,_,_)","steps(_,_)","committed_to(_,_,key)")
               agentArchClass arch.LocalMinerArch;
        toilet4 toiletminer.asl
               agentClass agent.SelectEvent
               beliefBaseClass agent.UniqueBelsBB("gsize(_,_,_)","depot(_,_,_)","steps(_,_)","committed_to(_,_,key)")
               agentArchClass arch.LocalMinerArch;
        toilet5 toiletminer.asl
               agentClass agent.SelectEvent
               beliefBaseClass agent.UniqueBelsBB("gsize(_,_,_)","depot(_,_,_)","steps(_,_)","committed_to(_,_,key)")
               agentArchClass arch.LocalMinerArch;
        toilet6 toiletminer.asl
               agentClass agent.SelectEvent
               beliefBaseClass agent.UniqueBelsBB("gsize(_,_,_)","depot(_,_,_)","steps(_,_)","committed_to(_,_,key)")
               agentArchClass arch.LocalMinerArch;
        """,
    },
    "hyperion": {
        "team_prefix": "hyper",
        "agents": """
        hyperionleader hyperionleader.asl
               beliefBaseClass agent.DiscardBelsBB("my_status","picked","committed_to","cell")
               ;

        hyper1 hyperionminer.asl
               agentClass agent.SelectEvent
               beliefBaseClass agent.UniqueBelsBB("gsize(_,_,_)","depot(_,_,_)","steps(_,_)","committed_to(_,_,key)")
               agentArchClass arch.LocalMinerArch;
        hyper2 hyperionminer.asl
               agentClass agent.SelectEvent
               beliefBaseClass agent.UniqueBelsBB("gsize(_,_,_)","depot(_,_,_)","steps(_,_)","committed_to(_,_,key)")
               agentArchClass arch.LocalMinerArch;
        hyper3 hyperionminer.asl
               agentClass agent.SelectEvent
               beliefBaseClass agent.UniqueBelsBB("gsize(_,_,_)","depot(_,_,_)","steps(_,_)","committed_to(_,_,key)")
               agentArchClass arch.LocalMinerArch;
        hyper4 hyperionminer.asl
               agentClass agent.SelectEvent
               beliefBaseClass agent.UniqueBelsBB("gsize(_,_,_)","depot(_,_,_)","steps(_,_)","committed_to(_,_,key)")
               agentArchClass arch.LocalMinerArch;
        hyper5 hyperionminer.asl
               agentClass agent.SelectEvent
               beliefBaseClass agent.UniqueBelsBB("gsize(_,_,_)","depot(_,_,_)","steps(_,_)","committed_to(_,_,key)")
               agentArchClass arch.LocalMinerArch;
        hyper6 hyperionminer.asl
               agentClass agent.SelectEvent
               beliefBaseClass agent.UniqueBelsBB("gsize(_,_,_)","depot(_,_,_)","steps(_,_)","committed_to(_,_,key)")
               agentArchClass arch.LocalMinerArch;
        """,
    },
    "nemesis": {
        "team_prefix": "nemesis",
        "agents": """
        nemesisleader nemesisleader.asl
               beliefBaseClass agent.DiscardBelsBB("my_status","picked","committed_to","cell")
               ;

        nemesis1 nemesisminer.asl
               agentClass agent.SelectEvent
               beliefBaseClass agent.UniqueBelsBB("gsize(_,_,_)","depot(_,_,_)","steps(_,_)","committed_to(_,_,key)")
               agentArchClass arch.LocalMinerArch;
        nemesis2 nemesisminer.asl
               agentClass agent.SelectEvent
               beliefBaseClass agent.UniqueBelsBB("gsize(_,_,_)","depot(_,_,_)","steps(_,_)","committed_to(_,_,key)")
               agentArchClass arch.LocalMinerArch;
        nemesis3 nemesisminer.asl
               agentClass agent.SelectEvent
               beliefBaseClass agent.UniqueBelsBB("gsize(_,_,_)","depot(_,_,_)","steps(_,_)","committed_to(_,_,key)")
               agentArchClass arch.LocalMinerArch;
        nemesis4 nemesisminer.asl
               agentClass agent.SelectEvent
               beliefBaseClass agent.UniqueBelsBB("gsize(_,_,_)","depot(_,_,_)","steps(_,_)","committed_to(_,_,key)")
               agentArchClass arch.LocalMinerArch;
        nemesis5 nemesisminer.asl
               agentClass agent.SelectEvent
               beliefBaseClass agent.UniqueBelsBB("gsize(_,_,_)","depot(_,_,_)","steps(_,_)","committed_to(_,_,key)")
               agentArchClass arch.LocalMinerArch;
        nemesis6 nemesisminer.asl
               agentClass agent.SelectEvent
               beliefBaseClass agent.UniqueBelsBB("gsize(_,_,_)","depot(_,_,_)","steps(_,_)","committed_to(_,_,key)")
               agentArchClass arch.LocalMinerArch;
        """,
    },
    # "stupid": {
        # "team_prefix": "stupid",
        # "agents": """
        # stupidleader stupidleader.asl
               # beliefBaseClass agent.DiscardBelsBB("my_status","picked","committed_to","cell")
               # ;

        # stupid1 stupidminer.asl
               # agentClass agent.SelectEvent
               # beliefBaseClass agent.UniqueBelsBB("gsize(_,_,_)","depot(_,_,_)","steps(_,_)","committed_to(_,_,key)")
               # agentArchClass arch.LocalMinerArch;
        # stupid2 stupidminer.asl
               # agentClass agent.SelectEvent
               # beliefBaseClass agent.UniqueBelsBB("gsize(_,_,_)","depot(_,_,_)","steps(_,_)","committed_to(_,_,key)")
               # agentArchClass arch.LocalMinerArch;
        # stupid3 stupidminer.asl
               # agentClass agent.SelectEvent
               # beliefBaseClass agent.UniqueBelsBB("gsize(_,_,_)","depot(_,_,_)","steps(_,_)","committed_to(_,_,key)")
               # agentArchClass arch.LocalMinerArch;
        # stupid4 stupidminer.asl
               # agentClass agent.SelectEvent
               # beliefBaseClass agent.UniqueBelsBB("gsize(_,_,_)","depot(_,_,_)","steps(_,_)","committed_to(_,_,key)")
               # agentArchClass arch.LocalMinerArch;
        # stupid5 stupidminer.asl
               # agentClass agent.SelectEvent
               # beliefBaseClass agent.UniqueBelsBB("gsize(_,_,_)","depot(_,_,_)","steps(_,_)","committed_to(_,_,key)")
               # agentArchClass arch.LocalMinerArch;
        # stupid6 stupidminer.asl
               # agentClass agent.SelectEvent
               # beliefBaseClass agent.UniqueBelsBB("gsize(_,_,_)","depot(_,_,_)","steps(_,_)","committed_to(_,_,key)")
               # agentArchClass arch.LocalMinerArch;
        # """,
    # },
}

# ── Logging helper ─────────────────────────────────────────────────────────────

class Tee:
    """Write to both stdout and a log file simultaneously."""
    def __init__(self, log_path: Path) -> None:
        self._log = log_path.open("w", encoding="utf-8")
        self._stdout = sys.stdout

    def write(self, data: str) -> int:
        self._stdout.write(data)
        self._log.write(data)
        return len(data)

    def flush(self) -> None:
        self._stdout.flush()
        self._log.flush()

    def close(self) -> None:
        self._log.close()

    # passthrough so print() works normally
    def __getattr__(self, name: str):
        return getattr(self._stdout, name)


def log(msg: str = "", *, tee: Tee | None = None) -> None:
    print(msg, flush=True)


# ── Jason / Java helpers ───────────────────────────────────────────────────────

def resolve_jason_launcher() -> Path:
    if JASON_JAR.exists():
        return JASON_JAR
    found = shutil.which("jason")
    if found:
        return Path(found)
    raise FileNotFoundError(
        "Jason launcher not found. Set JASON_HOME env var or put 'jason' on PATH."
    )


# def compile_sources() -> None:
    # CLASSES_DIR.mkdir(parents=True, exist_ok=True)
    # launcher = resolve_jason_launcher()
    # java_files = sorted(str(p) for p in PROJECT_ROOT.rglob("*.java"))
    # cmd = ["javac", "-cp", f"{launcher}:{SEARCH_JAR}", "-d", str(CLASSES_DIR), *java_files]
    # subprocess.run(cmd, cwd=PROJECT_ROOT, check=True)

def compile_sources() -> None:
    CLASSES_DIR.mkdir(parents=True, exist_ok=True)
    launcher = resolve_jason_launcher()
    
    # Ignore any files that end with "Old.java" so backups don't break the build
    java_files = sorted(
        str(p) for p in PROJECT_ROOT.rglob("*.java") if not p.name.endswith("Old.java")
    )
    
    cmd = ["javac", "-cp", f"{launcher}:{SEARCH_JAR}", "-d", str(CLASSES_DIR), *java_files]
    subprocess.run(cmd, cwd=PROJECT_ROOT, check=True)

# ── MAS2J generation ───────────────────────────────────────────────────────────

def make_mas2j(path: Path, world: int, red: str, blue: str,
               sleep_ms: int, visualize: bool) -> None:
    red_block  = textwrap.indent(textwrap.dedent(STRATEGIES[red]["agents"]).strip(),  "        ")
    blue_block = textwrap.indent(textwrap.dedent(STRATEGIES[blue]["agents"]).strip(), "        ")
    asl_path   = PROJECT_ROOT / "asl"
    gui        = "yes" if visualize else "no"
    content = textwrap.dedent(f"""
        MAS miners {{
            environment: env.MiningEnvironment({world}, {sleep_ms}, {gui}, "{STRATEGIES[red]['team_prefix']}", "{STRATEGIES[blue]['team_prefix']}", 1000)

            agents:
        {red_block}

        {blue_block}

            aslSourcePath: "{asl_path}";
        }}
    """).strip() + "\n"
    path.write_text(content, encoding="utf-8")


def write_log_config(path: Path, match_log: Path) -> None:
    path.write_text(
        textwrap.dedent(f"""
            handlers = java.util.logging.FileHandler
            .level = INFO
            java.util.logging.FileHandler.pattern = {match_log}
            java.util.logging.FileHandler.limit = 50000000
            java.util.logging.FileHandler.count = 1
            java.util.logging.FileHandler.formatter = jason.runtime.MASConsoleLogFormatter
            java.level=OFF
            javax.level=OFF
            sun.level=OFF
        """).strip() + "\n",
        encoding="utf-8",
    )


# ── Result parsing ─────────────────────────────────────────────────────────────

FINAL_SCORE_RE   = re.compile(r"Red x Blue = (\d+) x (\d+)")
ALL_GOLD_RE      = re.compile(r"All golds collected in (\d+) cycles! Result \(red x blue\) = (\d+) x (\d+)")
STDOUT_RESULT_RE = re.compile(r"MATCH_RESULT reason=(\S+) world=(\d+) step=(\d+) red=(\d+) blue=(\d+)")


def parse_match_log(log_path: Path) -> dict | None:
    if not log_path.exists():
        return None
    content = log_path.read_text(encoding="utf-8", errors="replace")
    m = ALL_GOLD_RE.search(content)
    if m:
        step, red, blue = m.groups()
        return {"reason": "all_gold", "step": int(step), "red": int(red), "blue": int(blue)}
    m = FINAL_SCORE_RE.search(content)
    if m:
        red, blue = m.groups()
        cycles = re.findall(r"Cycle (\d+) finished", content)
        step = int(cycles[-1]) if cycles else 0
        return {"reason": "max_steps", "step": step, "red": int(red), "blue": int(blue)}
    return None


def parse_stdout_result(stdout_path: Path) -> dict | None:
    if not stdout_path.exists():
        return None
    content = stdout_path.read_text(encoding="utf-8", errors="replace")
    m = STDOUT_RESULT_RE.search(content)
    if not m:
        return None
    reason, world, step, red, blue = m.groups()
    return {"reason": reason, "world": int(world), "step": int(step),
            "red": int(red), "blue": int(blue)}


# ── Match runner ───────────────────────────────────────────────────────────────

def run_match(world: int, red: str, blue: str,
              sleep_ms: int, timeout_s: int, visualize: bool,
              session_dir: Path) -> dict:
    """Run one match and return a result dict. Never raises — failed matches get outcome='error'."""
    tmpdir = Path(tempfile.mkdtemp(prefix="gm-eval-"))
    mas2j_file  = tmpdir / f"match-{world}-{red}-vs-{blue}.mas2j"
    log_config  = tmpdir / "logging.properties"
    stdout_log  = tmpdir / "stdout.log"
    match_log   = tmpdir / "match.log"

    make_mas2j(mas2j_file, world, red, blue, sleep_ms, visualize)
    write_log_config(log_config, match_log)

    step_timeout_ms = 1000 if visualize else 1
    start_delay_ms  = 1500 if visualize else 0
    launcher = resolve_jason_launcher()
    cmd = [
        "java",
        f"-Djava.awt.headless={'false' if visualize else 'true'}",
        f"-Dgoldminers.step.timeout.ms={step_timeout_ms}",
        f"-Dgoldminers.start.delay.ms={start_delay_ms}",
        "-cp", f"{launcher}:{CLASSES_DIR}:{SEARCH_JAR}:.",
        "tools.HeadlessRunner",
        str(mas2j_file),
        str(log_config),
    ]

    base: dict = {
        "world": world, "red_strategy": red, "blue_strategy": blue,
        "red": 0, "blue": 0, "step": 0,
        "reason": "error", "outcome": "error",
        "stdout_log": str(stdout_log), "match_log": str(match_log),
    }

    try:
        parsed: dict | None = None
        with stdout_log.open("w", encoding="utf-8") as out:
            proc = subprocess.Popen(cmd, cwd=PROJECT_ROOT, stdout=out, stderr=subprocess.STDOUT)
            deadline = time.time() + timeout_s
            while time.time() < deadline:
                parsed = parse_stdout_result(stdout_log) or parse_match_log(match_log)
                if parsed:
                    break
                if proc.poll() is not None:
                    parsed = parse_stdout_result(stdout_log) or parse_match_log(match_log)
                    break
                time.sleep(0.2)

            if parsed is None:
                proc.kill()
                proc.wait(timeout=5)
                base["reason"] = "timeout"
                base["outcome"] = "error"
                return base

            if proc.poll() is None:
                proc.terminate()
                try:
                    proc.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    proc.kill()
                    proc.wait(timeout=5)

        red_score  = int(parsed["red"])
        blue_score = int(parsed["blue"])
        if red_score > blue_score:
            outcome = "red_win"
        elif blue_score > red_score:
            outcome = "blue_win"
        else:
            outcome = "draw"

        return {
            **base,
            "red":     red_score,
            "blue":    blue_score,
            "step":    parsed["step"],
            "reason":  parsed["reason"],
            "outcome": outcome,
        }

    except Exception as exc:
        base["reason"] = f"exception:{exc}"
        return base


# ── Statistics helpers ─────────────────────────────────────────────────────────

def build_strategy_stats(
    matches: list[dict], strategy_names: list[str]
) -> dict[str, dict]:
    """Aggregate per-strategy stats across all matches."""
    stats: dict[str, dict] = {
        s: {"wins": 0, "draws": 0, "losses": 0, "gold": [], "errors": 0}
        for s in strategy_names
    }

    for m in matches:
        if m["outcome"] == "error":
            for s in (m["red_strategy"], m["blue_strategy"]):
                stats[s]["errors"] += 1
            continue

        red_s  = m["red_strategy"]
        blue_s = m["blue_strategy"]
        outcome = m["outcome"]

        if outcome == "red_win":
            stats[red_s]["wins"]   += 1
            stats[blue_s]["losses"] += 1
        elif outcome == "blue_win":
            stats[blue_s]["wins"]  += 1
            stats[red_s]["losses"] += 1
        else:
            stats[red_s]["draws"]  += 1
            stats[blue_s]["draws"] += 1

        stats[red_s]["gold"].append(int(m["red"]))
        stats[blue_s]["gold"].append(int(m["blue"]))

    return stats


def build_h2h(matches: list[dict]) -> dict[tuple[str, str], dict]:
    """Build head-to-head record for every unordered pair of strategies."""
    h2h: dict[tuple[str, str], dict] = {}

    def key(a: str, b: str) -> tuple[str, str]:
        return (min(a, b), max(a, b))

    for m in matches:
        if m["outcome"] == "error":
            continue
        red_s, blue_s = m["red_strategy"], m["blue_strategy"]
        k = key(red_s, blue_s)
        if k not in h2h:
            h2h[k] = {k[0]: {"wins": 0, "draws": 0, "losses": 0},
                      k[1]: {"wins": 0, "draws": 0, "losses": 0}}
        if m["outcome"] == "red_win":
            h2h[k][red_s]["wins"]    += 1
            h2h[k][blue_s]["losses"] += 1
        elif m["outcome"] == "blue_win":
            h2h[k][blue_s]["wins"]   += 1
            h2h[k][red_s]["losses"]  += 1
        else:
            h2h[k][red_s]["draws"]   += 1
            h2h[k][blue_s]["draws"]  += 1

    return h2h


# ── Table printing ─────────────────────────────────────────────────────────────

def fmt_pct(num: int, den: int) -> str:
    if den == 0:
        return "  -  "
    return f"{100*num/den:5.1f}%"


def fmt_f(val: float) -> str:
    return f"{val:6.2f}"


def print_leaderboard(stats: dict[str, dict], strategy_names: list[str]) -> None:
    # sort by win%, then avg gold
    def sort_key(s: str) -> tuple:
        st = stats[s]
        gp = st["wins"] + st["draws"] + st["losses"]
        wr = st["wins"] / gp if gp else 0
        avg = statistics.mean(st["gold"]) if st["gold"] else 0
        return (-wr, -avg)

    ranked = sorted(strategy_names, key=sort_key)

    cols = ["Rank", "Strategy", "GP", "W", "D", "L", "Win%", "AvgGold", "MaxGold", "TotalGold", "Errors"]
    rows = []
    for rank, s in enumerate(ranked, 1):
        st = stats[s]
        gp = st["wins"] + st["draws"] + st["losses"]
        avg  = statistics.mean(st["gold"]) if st["gold"] else 0.0
        maxi = max(st["gold"]) if st["gold"] else 0
        total = sum(st["gold"])
        rows.append([
            str(rank), s, str(gp),
            str(st["wins"]), str(st["draws"]), str(st["losses"]),
            fmt_pct(st["wins"], gp).strip(),
            f"{avg:.2f}", str(maxi), str(total), str(st["errors"]),
        ])

    # compute column widths
    widths = [max(len(cols[i]), *(len(r[i]) for r in rows)) for i in range(len(cols))]
    sep = "+-" + "-+-".join("-" * w for w in widths) + "-+"
    hdr = "| " + " | ".join(cols[i].ljust(widths[i]) for i in range(len(cols))) + " |"

    print()
    print("=" * len(sep))
    print("STRATEGY LEADERBOARD".center(len(sep)))
    print("=" * len(sep))
    print(sep)
    print(hdr)
    print(sep)
    for r in rows:
        print("| " + " | ".join(r[i].ljust(widths[i]) for i in range(len(cols))) + " |")
    print(sep)


def print_h2h_matrix(h2h: dict, strategy_names: list[str]) -> None:
    """Print a head-to-head wins matrix (rows=strategy, cols=opponent)."""
    names = strategy_names
    # cell: "W-D-L" of row strategy against col strategy
    cell_w = max(len(n) for n in names)
    cell_w = max(cell_w, 7)  # "W - D - L" = 9 chars min

    print()
    print("=" * ((cell_w + 3) * (len(names) + 1) + 1))
    print("HEAD-TO-HEAD MATRIX  (W - D - L  from row strategy's perspective)".center(
        (cell_w + 3) * (len(names) + 1) + 1))
    print("=" * ((cell_w + 3) * (len(names) + 1) + 1))

    # header row
    header = " " * cell_w + " | " + " | ".join(n.center(cell_w) for n in names)
    print(header)
    print("-" * len(header))

    def key(a: str, b: str) -> tuple[str, str]:
        return (min(a, b), max(a, b))

    for row_s in names:
        cells = []
        for col_s in names:
            if row_s == col_s:
                cells.append("  ---  ".center(cell_w))
            else:
                k = key(row_s, col_s)
                if k in h2h:
                    rec = h2h[k][row_s]
                    cell = f"{rec['wins']}-{rec['draws']}-{rec['losses']}"
                else:
                    cell = "  n/a  "
                cells.append(cell.center(cell_w))
        print(row_s.ljust(cell_w) + " | " + " | ".join(cells))


def print_world_breakdown(matches: list[dict], strategy_names: list[str]) -> None:
    """Per-world average gold per strategy."""
    worlds = sorted({m["world"] for m in matches if m["outcome"] != "error"})
    if not worlds:
        return

    world_gold: dict[int, dict[str, list[int]]] = {
        w: {s: [] for s in strategy_names} for w in worlds
    }
    for m in matches:
        if m["outcome"] == "error":
            continue
        world_gold[m["world"]][m["red_strategy"]].append(int(m["red"]))
        world_gold[m["world"]][m["blue_strategy"]].append(int(m["blue"]))

    col_w = max(len(s) for s in strategy_names)
    col_w = max(col_w, 6)

    print()
    print("=" * ((col_w + 3) * (len(strategy_names) + 1) + 1))
    print("AVG GOLD PER WORLD".center((col_w + 3) * (len(strategy_names) + 1) + 1))
    print("=" * ((col_w + 3) * (len(strategy_names) + 1) + 1))

    header = "World".ljust(col_w) + " | " + " | ".join(s.center(col_w) for s in strategy_names)
    print(header)
    print("-" * len(header))
    for w in worlds:
        cells = []
        for s in strategy_names:
            glist = world_gold[w][s]
            cells.append((f"{statistics.mean(glist):.1f}" if glist else "-").center(col_w))
        print(str(w).ljust(col_w) + " | " + " | ".join(cells))


# ── CSV writers ────────────────────────────────────────────────────────────────

MATCH_FIELDS = [
    "matchup_id", "world", "run", "red_strategy", "blue_strategy",
    "red", "blue", "diff", "outcome", "reason", "step",
    "stdout_log", "match_log",
]

SUMMARY_FIELDS = [
    "rank", "strategy", "games_played", "wins", "draws", "losses",
    "win_pct", "avg_gold", "max_gold", "total_gold", "errors",
]

H2H_FIELDS = ["strategy_a", "strategy_b", "a_wins", "draws", "b_wins"]


def write_matches_csv(path: Path, rows: list[dict]) -> None:
    with path.open("w", newline="", encoding="utf-8") as fh:
        w = csv.DictWriter(fh, fieldnames=MATCH_FIELDS, extrasaction="ignore")
        w.writeheader()
        w.writerows(rows)


def write_summary_csv(path: Path, stats: dict[str, dict],
                      ranked: list[str]) -> None:
    with path.open("w", newline="", encoding="utf-8") as fh:
        w = csv.DictWriter(fh, fieldnames=SUMMARY_FIELDS)
        w.writeheader()
        for rank, s in enumerate(ranked, 1):
            st = stats[s]
            gp = st["wins"] + st["draws"] + st["losses"]
            avg  = statistics.mean(st["gold"]) if st["gold"] else 0.0
            maxi = max(st["gold"]) if st["gold"] else 0
            w.writerow({
                "rank": rank, "strategy": s, "games_played": gp,
                "wins": st["wins"], "draws": st["draws"], "losses": st["losses"],
                "win_pct": round(100 * st["wins"] / gp, 2) if gp else 0,
                "avg_gold": round(avg, 2), "max_gold": maxi,
                "total_gold": sum(st["gold"]), "errors": st["errors"],
            })


def write_h2h_csv(path: Path, h2h: dict) -> None:
    with path.open("w", newline="", encoding="utf-8") as fh:
        w = csv.DictWriter(fh, fieldnames=H2H_FIELDS)
        w.writeheader()
        for (a, b), rec in sorted(h2h.items()):
            w.writerow({
                "strategy_a": a, "strategy_b": b,
                "a_wins": rec[a]["wins"],
                "draws":  rec[a]["draws"],
                "b_wins": rec[b]["wins"],
            })


# ── Incremental CSV writer (flush after every match) ──────────────────────────

class IncrementalMatchWriter:
    def __init__(self, path: Path) -> None:
        self._fh = path.open("w", newline="", encoding="utf-8")
        self._w  = csv.DictWriter(self._fh, fieldnames=MATCH_FIELDS, extrasaction="ignore")
        self._w.writeheader()
        self._fh.flush()

    def write(self, row: dict) -> None:
        self._w.writerow(row)
        self._fh.flush()

    def close(self) -> None:
        self._fh.close()


# ── Main ───────────────────────────────────────────────────────────────────────

def main() -> int:
    parser = argparse.ArgumentParser(
        description="Run all strategy combinations and produce a leaderboard.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    parser.add_argument(
        "--strategies", nargs="+", choices=sorted(STRATEGIES),
        default=sorted(STRATEGIES),
        help="Subset of strategies to test (default: all).",
    )
    parser.add_argument(
        "--worlds", nargs="+", type=int, default=[11, 12, 13],
        help="World seeds to run (default: 11 12 13).",
    )
    parser.add_argument(
        "--runs", type=int, default=2,
        help="Runs per (matchup, world) pair (default: 2).",
    )
    parser.add_argument(
        "--sleep-ms", type=int, default=0,
        help="Step sleep in ms — 0 for fastest headless (default: 0).",
    )
    parser.add_argument(
        "--timeout-s", type=int, default=180,
        help="Per-match timeout in seconds (default: 180).",
    )
    parser.add_argument(
        "--no-compile", action="store_true",
        help="Skip javac compilation step.",
    )
    args = parser.parse_args()

    strategies = args.strategies
    if len(strategies) < 2:
        parser.error("Need at least 2 strategies to compare.")

    # Create session output directory
    ts = datetime.now().strftime("%Y-%m-%d_%H-%M-%S")
    session_dir = RESULTS_ROOT / ts
    session_dir.mkdir(parents=True, exist_ok=True)

    matches_csv_path = session_dir / "matches.csv"
    summary_csv_path = session_dir / "summary.csv"
    h2h_csv_path     = session_dir / "head_to_head.csv"
    log_path         = session_dir / "session.log"

    tee = Tee(log_path)
    sys.stdout = tee

    print(f"Session directory: {session_dir}")
    print(f"Strategies:        {', '.join(strategies)}")
    print(f"Worlds:            {args.worlds}")
    print(f"Runs per matchup:  {args.runs}")
    print(f"Timeout:           {args.timeout_s}s")
    print(f"Started:           {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")

    # Compile
    if not args.no_compile:
        print("\nCompiling Java sources...")
        try:
            compile_sources()
            print("Compilation OK.")
        except subprocess.CalledProcessError as e:
            print(f"ERROR: Compilation failed: {e}")
            sys.stdout = tee._stdout
            tee.close()
            return 1

    # Build all ordered pairs (A vs B  AND  B vs A)
    pairs = list(itertools.permutations(strategies, 2))
    total_matches = len(pairs) * len(args.worlds) * args.runs
    print(f"\nMatchups:          {len(pairs)} ordered pairs")
    print(f"Total matches:     {total_matches}")
    print()

    all_matches: list[dict] = []
    inc_writer = IncrementalMatchWriter(matches_csv_path)
    match_num = 0

    try:
        for red, blue in pairs:
            print(f"{'='*60}")
            print(f"  {red.upper()}  (red)  vs  {blue.upper()}  (blue)")
            print(f"{'='*60}")
            matchup_wins   = {red: 0, blue: 0, "draw": 0, "error": 0}

            for world in args.worlds:
                for run in range(1, args.runs + 1):
                    match_num += 1
                    matchup_id = f"{red}_vs_{blue}_w{world}_r{run}"
                    pct = 100 * match_num / total_matches
                    print(
                        f"  [{match_num:>4}/{total_matches}] ({pct:5.1f}%)  "
                        f"world={world} run={run}/{args.runs}  ...",
                        end="", flush=True,
                    )

                    result = run_match(world, red, blue, args.sleep_ms,
                                       args.timeout_s, False, session_dir)
                    result["run"]        = run
                    result["matchup_id"] = matchup_id
                    result["diff"]       = int(result["blue"]) - int(result["red"])

                    outcome = result["outcome"]
                    winner = red if outcome == "red_win" else (blue if outcome == "blue_win" else outcome)
                    matchup_wins[outcome if outcome in ("draw", "error") else winner] += 1

                    tag = (
                        f"red={result['red']} blue={result['blue']}  "
                        f"[{outcome.upper()}]  reason={result['reason']}"
                    )
                    print(f"  {tag}")

                    all_matches.append(result)
                    inc_writer.write(result)

            # mini-summary per matchup
            valid = [m for m in all_matches
                     if m["red_strategy"] == red and m["blue_strategy"] == blue
                     and m["outcome"] != "error"]
            if valid:
                avg_red  = statistics.mean(int(m["red"])  for m in valid)
                avg_blue = statistics.mean(int(m["blue"]) for m in valid)
                print(
                    f"  => {red}: {matchup_wins.get(red,0)}W "
                    f"| {matchup_wins['draw']}D "
                    f"| {matchup_wins.get(blue,0)}L  "
                    f"avg gold: {avg_red:.1f} vs {avg_blue:.1f}"
                )
            print()

    except KeyboardInterrupt:
        print("\n\n[Interrupted by user — saving partial results]")

    finally:
        inc_writer.close()

    # ── Final statistics ─────────────────────────────────────────────────────
    print()
    print("=" * 60)
    print("COMPUTING FINAL STATISTICS")
    print("=" * 60)

    stats = build_strategy_stats(all_matches, strategies)
    h2h   = build_h2h(all_matches)

    def sort_key(s: str) -> tuple:
        st = stats[s]
        gp = st["wins"] + st["draws"] + st["losses"]
        wr = st["wins"] / gp if gp else 0
        avg = statistics.mean(st["gold"]) if st["gold"] else 0
        return (-wr, -avg)

    ranked = sorted(strategies, key=sort_key)

    print_leaderboard(stats, strategies)
    print_h2h_matrix(h2h, strategies)
    print_world_breakdown(all_matches, strategies)

    # ── Save CSVs ─────────────────────────────────────────────────────────────
    write_summary_csv(summary_csv_path, stats, ranked)
    write_h2h_csv(h2h_csv_path, h2h)
    # matches.csv already written incrementally

    print()
    print(f"Finished:   {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print(f"Results in: {session_dir}")
    print(f"  matches.csv    — {len(all_matches)} match rows")
    print(f"  summary.csv    — per-strategy leaderboard")
    print(f"  head_to_head.csv")
    print(f"  session.log    — full output")

    sys.stdout = tee._stdout
    tee.close()
    return 0


if __name__ == "__main__":
    sys.exit(main())
