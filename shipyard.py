#!/usr/bin/env python3
"""Shipyard collector: what shipped today across every local git repo.

Read-only. Walks the repo roots, runs `git log` in each, prints one JSON
object. Results are cached per repo keyed on HEAD mtime of .git so a poll
of ~200 repos stays cheap.
"""
import datetime as dt
import json
import os
import subprocess
import sys
from concurrent.futures import ThreadPoolExecutor

HOME = os.path.expanduser("~")
ROOTS = [os.path.join(HOME, "Projects")]
EXTRA = [os.path.join(HOME, ".claude"), os.path.join(HOME, ".config", "omarchy")]
SKIP = {"_archive", "node_modules"}
WEEKS = 16


def find_repos():
    repos = [p for p in EXTRA if os.path.isdir(os.path.join(p, ".git"))]
    for root in ROOTS:
        try:
            level1 = sorted(os.listdir(root))
        except OSError:
            continue
        for name in level1:
            if name in SKIP or name.startswith("."):
                continue
            d = os.path.join(root, name)
            if os.path.isdir(os.path.join(d, ".git")):
                repos.append(d)
                continue
            try:
                for sub in sorted(os.listdir(d)):
                    s = os.path.join(d, sub)
                    if sub not in SKIP and os.path.isdir(os.path.join(s, ".git")):
                        repos.append(s)
            except OSError:
                pass
    return repos


def emails():
    out = set()
    try:
        e = subprocess.run(["git", "config", "--global", "user.email"],
                           capture_output=True, text=True, timeout=5).stdout.strip()
        if e:
            out.add(e.lower())
    except Exception:
        pass
    out.add("noreply@anthropic.com")
    return out


def scan(repo, since, mine):
    fmt = "%x1e%H%x1f%at%x1f%ae%x1f%s"
    try:
        r = subprocess.run(
            ["git", "-C", repo, "log", "--all", "--no-merges", "--since=" + since,
             "--pretty=format:" + fmt, "--shortstat"],
            capture_output=True, text=True, timeout=20)
    except Exception:
        return []
    if r.returncode != 0:
        return []
    out, seen = [], set()
    for chunk in r.stdout.split("\x1e"):
        chunk = chunk.strip()
        if not chunk:
            continue
        head, _, rest = chunk.partition("\n")
        parts = head.split("\x1f")
        if len(parts) < 4 or parts[0] in seen:
            continue
        seen.add(parts[0])
        if mine and parts[2].lower() not in mine:
            continue
        add = dele = 0
        for tok in rest.replace(",", "\n").splitlines():
            tok = tok.strip()
            if "insertion" in tok:
                add = int(tok.split()[0])
            elif "deletion" in tok:
                dele = int(tok.split()[0])
        out.append({"sha": parts[0], "t": int(parts[1]), "subject": parts[3][:140],
                    "add": add, "del": dele})
    return out


CACHE = os.path.join(HOME, ".cache", "shipyard", "cache.json")


def stamp(repo):
    g = os.path.join(repo, ".git")
    v = []
    for f in ("logs/HEAD", "packed-refs", "HEAD", "FETCH_HEAD"):
        try:
            v.append(os.stat(os.path.join(g, f)).st_mtime_ns)
        except OSError:
            v.append(0)
    try:
        for dp, _, fs in os.walk(os.path.join(g, "refs")):
            for f in fs:
                v.append(os.stat(os.path.join(dp, f)).st_mtime_ns)
    except OSError:
        pass
    return str(max(v))


def main():
    now = dt.datetime.now()
    midnight = now.replace(hour=0, minute=0, second=0, microsecond=0)
    start = midnight - dt.timedelta(days=WEEKS * 7 - 1)
    mine = emails()
    repos = find_repos()
    day = midnight.strftime("%Y-%m-%d")
    try:
        cache = json.load(open(CACHE))
        if cache.get("day") != day:
            cache = {}
    except Exception:
        cache = {}
    repos_c = cache.get("repos", {})

    def work(p):
        st = stamp(p)
        hit = repos_c.get(p)
        if hit and hit.get("stamp") == st:
            return p, st, hit["commits"]
        return p, st, scan(p, start.isoformat(), mine)

    with ThreadPoolExecutor(max_workers=6) as ex:
        triples = list(ex.map(work, repos))
    results = [(p, c) for p, _, c in triples]
    try:
        os.makedirs(os.path.dirname(CACHE), exist_ok=True)
        tmp = CACHE + ".tmp"
        with open(tmp, "w") as f:
            json.dump({"day": day, "repos": {p: {"stamp": st, "commits": c} for p, st, c in triples}}, f)
        os.replace(tmp, CACHE)
    except OSError:
        pass

    days = {}
    hours = [0] * 24
    feed, repo_today = [], {}
    add = dele = 0
    for path, commits in results:
        name = os.path.relpath(path, HOME).replace("Projects/", "")
        for c in commits:
            d = dt.datetime.fromtimestamp(c["t"])
            key = d.strftime("%Y-%m-%d")
            days[key] = days.get(key, 0) + 1
            if d >= midnight:
                hours[d.hour] += 1
                add += c["add"]
                dele += c["del"]
                repo_today[name] = repo_today.get(name, 0) + 1
                feed.append({"repo": name, "path": path, "sha": c["sha"][:10],
                             "time": d.strftime("%H:%M"), "t": c["t"],
                             "subject": c["subject"], "add": c["add"], "del": c["del"]})

    streak = 0
    cur = midnight
    if days.get(cur.strftime("%Y-%m-%d"), 0) == 0:
        cur -= dt.timedelta(days=1)  # today not started yet: streak still alive
    while days.get(cur.strftime("%Y-%m-%d"), 0) > 0:
        streak += 1
        cur -= dt.timedelta(days=1)

    heat = []
    for i in range(WEEKS * 7):
        k = (start + dt.timedelta(days=i)).strftime("%Y-%m-%d")
        heat.append(days.get(k, 0))
    # pad so column 0 starts on Monday
    lead = start.weekday()
    week_total = sum(heat[-7:])
    best = max(heat) if heat else 0
    feed.sort(key=lambda x: -x["t"])
    top = sorted(repo_today.items(), key=lambda kv: -kv[1])[:8]
    print(json.dumps({
        "ok": True, "generated": now.strftime("%H:%M:%S"),
        "today": len(feed), "repos": len(repo_today), "scanned": len(repos),
        "add": add, "del": dele, "streak": streak, "week": week_total,
        "best": best, "heat": heat, "lead": lead, "hours": hours,
        "top": [{"repo": r, "n": n} for r, n in top], "feed": feed[:200],
    }))


if __name__ == "__main__":
    try:
        main()
    except Exception as e:  # fail loudly but as JSON so the bar can show it
        print(json.dumps({"ok": False, "error": str(e)}))
        sys.exit(1)
