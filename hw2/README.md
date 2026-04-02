# HW2 Gold Miners

This repository contains the `gold-miners-II` assignment setup plus a `smart` team variant and an evaluation script.

## Added Strategy Files

- `asl/smart.asl`
- `asl/smart_allocation_protocol.asl`
- `asl/smartleader.asl`
- `asl/smart1.asl` to `asl/smart6.asl`

The evaluator also uses explicit wrapper agents for the bundled teams:

- `asl/dummy1.asl` to `asl/dummy6.asl`
- `asl/miner1.asl` to `asl/miner6.asl`

## Added Tooling

- `evaluate.py`: headless or visual match runner for comparing `dummy`, `example`, and `smart`
- `tools/HeadlessRunner.java`: lightweight launcher used by `evaluate.py`

Support files copied to keep the evaluator working in this repo:

- `env/MiningEnvironment.java`
- `env/WorldFactory.java`
- `arch/MinerArch.java`
- `lib/search.jar`

## Running Evaluation

From the repository root:

```bash
python3 evaluate.py --red example --blue smart --worlds 11 12 13 --runs 5 --timeout-s 60 --sleep-ms 0 --csv /tmp/gm-results.csv
```

Visual run:

```bash
python3 evaluate.py --red dummy --blue smart --worlds 11 --runs 1 --sleep-ms 150 --timeout-s 120 --visualize
```

## Jason Path

The evaluator looks for Jason in this order:

1. `JASON_HOME/bin/jason`
2. `/Users/ampapacek/jason-bin-3/bin/jason`
3. `jason` on `PATH`

If needed:

```bash
export JASON_HOME=/path/to/jason-bin-3
```

## Notes

- The contest-relevant worlds are `11`, `12`, and `13`.
- The current `smart` team is a tuned roaming/allocation strategy; it is competitive with the bundled example but still stochastic.
