"""Fails a pull request whose added lines, title, description or commit messages name a team member.

Reads the team from the TEAM_MEMBERS environment variable, which holds the organisation secret of the same name: a JSON object
of GitHub login to that person's entry, for example

    {"adalogin": {"slack": "U0123ABCD", "names": ["Ada", "Lovelace"]}}

Each login and each of its names is refused. The board sync reads the same secret for Slack mentions, so `slack` is
the person's Slack member ID; this check ignores it. A word matches whole and in any letter case, so
`ada@example.com` matches `Ada` and `Adaptive` does not. A name that is also an everyday word or code is written
`exact:Will`, and then matches only in that letter case, so `will` and `WILL` pass. Adding a person is one entry in the
secret. An unset, unreadable or empty TEAM_MEMBERS fails the check: nothing could be checked.

A description may address a team member by @login, the way a review request does: before a description line is
searched, each `@` followed by a team login, in any letter case, is removed. So `@adalogin please review` passes, while
`thanks Ada (@adalogin)` still fails on the name, `@Ada` fails because Ada is a name and not a login, and an email such
as `ada@example.com` still fails. Titles, added lines and commit messages are searched as written.

Run inside a checkout that holds both commits:
    python3 check.py --base <sha> --head <sha>
with TEAM_MEMBERS, PR_TITLE and PR_BODY in the environment. Exits 1 and prints each hit, or prints "no names".
"""
import argparse
import json
import os
import re
import subprocess
import sys

# Added lines in these files are not read: lock files carry hashes and URLs, not prose.
SKIPPED_FILES = re.compile(r"(^|/)(package-lock\.json|yarn\.lock|pnpm-lock\.yaml|[^/]*\.lock)$")
# The deploy workflows map GitHub logins to Slack mentions, so their `name="..."` lines need names.
SLACK_MAP_FILE = re.compile(r"^\.github/workflows/[^/]+\.ya?ml$")
# An @mention: an `@` that does not follow a word or a dot (so not the `@` of an email address), then a login.
MENTION = re.compile(r"(?<![A-Za-z0-9_.])@([A-Za-z0-9-]+)")


def read_names(raw):
    """Returns (words matched in any letter case, words matched only as written, logins) from the TEAM_MEMBERS JSON."""
    try:
        team = json.loads(raw or "")
    except ValueError:
        sys.exit("TEAM_MEMBERS is not JSON, so nothing can be checked")
    if not isinstance(team, dict):
        sys.exit("TEAM_MEMBERS is not a JSON object of GitHub login to entry, so nothing can be checked")
    any_case, exact = [], []
    for login, entry in team.items():
        any_case.append(login)
        names = entry.get("names", []) if isinstance(entry, dict) else []
        if not isinstance(names, list):
            sys.exit(f"TEAM_MEMBERS: the names of {login} are not a list, so nothing can be checked")
        for name in names:
            if not isinstance(name, str) or not name.strip():
                sys.exit(f"TEAM_MEMBERS: {login} has a name that is not text, so nothing can be checked")
            if name.startswith("exact:"):
                exact.append(name[len("exact:"):])
            else:
                any_case.append(name)
    if not any_case and not exact:
        sys.exit("TEAM_MEMBERS names nobody, so nothing can be checked")
    return any_case, exact, list(team)


def whole_words(words, flags=0):
    if not words:
        return None
    alternatives = "|".join(re.escape(w) for w in sorted(set(words), key=len, reverse=True))
    return re.compile(rf"(?<![A-Za-z0-9_])(?:{alternatives})(?![A-Za-z0-9_])", flags)


class Names:
    def __init__(self, any_case, exact, logins):
        self.patterns = [p for p in (whole_words(any_case, re.IGNORECASE), whole_words(exact)) if p]
        self.logins = {login.lower() for login in logins}

    def search(self, text):
        return any(p.search(text) for p in self.patterns)

    def without_mentions(self, text):
        """The text with each @mention of a team login removed; any other @word is left to be searched."""
        return MENTION.sub(lambda m: "" if m.group(1).lower() in self.logins else m.group(0), text)


def git(*args):
    out = subprocess.run(["git", *args], check=True, capture_output=True).stdout
    return out.decode("utf-8", errors="replace")


def added_lines(base, head):
    """Yields (path, line number, text) for each line the change adds."""
    diff = git("-c", "core.quotePath=false", "diff", "--unified=0", "--no-color", "--no-ext-diff", "--no-renames",
               f"{base}...{head}")
    # Split on newlines only: a carriage return or form feed inside a line is part of that line.
    lines = iter(diff.split("\n"))
    path = None
    for line in lines:
        if line.startswith("+++ "):
            # Git ends the header with a tab when the path has a space.
            target = line[4:].rstrip("\t")
            if target.startswith('"') and target.endswith('"'):
                target = target[1:-1]
            path = target[2:] if target.startswith("b/") else None
        elif line.startswith("@@ "):
            # Inside a hunk every line is content, whatever it starts with, so the header's counts decide where it ends.
            m = re.match(r"@@ -\d+(?:,(\d+))? \+(\d+)(?:,(\d+))? @@", line)
            removed = int(m.group(1)) if m.group(1) is not None else 1
            number = int(m.group(2))
            added = int(m.group(3)) if m.group(3) is not None else 1
            while removed > 0 or added > 0:
                body = next(lines)
                if body.startswith("-"):
                    removed -= 1
                elif body.startswith("+"):
                    added -= 1
                    if path is not None:
                        yield path, number, body[1:]
                    number += 1


def commit_messages(base, head):
    """Yields (short sha, message) for each commit the pull request adds."""
    log = git("log", "--format=%H%x00%B%x00", f"{base}..{head}")
    parts = log.split("\x00")
    for sha, message in zip(parts[0::2], parts[1::2]):
        yield sha.strip()[:8], message


def find_hits(names, base, head, title, body):
    hits = []
    for path, number, text in added_lines(base, head):
        if SKIPPED_FILES.search(path):
            continue
        if SLACK_MAP_FILE.match(path) and 'name="' in text:
            continue
        if names.search(text):
            hits.append(f"{path}:{number}: {text.strip()}")
    if names.search(title):
        hits.append(f"title: {title.strip()}")
    for number, text in enumerate(body.splitlines(), 1):
        if names.search(names.without_mentions(text)):
            hits.append(f"description:{number}: {text.strip()}")
    for sha, message in commit_messages(base, head):
        for number, text in enumerate(message.splitlines(), 1):
            if names.search(text):
                hits.append(f"commit {sha}:{number}: {text.strip()}")
    return hits


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--base", required=True)
    parser.add_argument("--head", required=True)
    args = parser.parse_args()
    names = Names(*read_names(os.environ.get("TEAM_MEMBERS")))
    hits = find_hits(names, args.base, args.head, os.environ.get("PR_TITLE", ""), os.environ.get("PR_BODY", ""))
    if hits:
        print("These lines name a person. Say what the code does instead, and name nobody:")
        for hit in hits:
            print(hit)
        sys.exit(1)
    print("no names")


if __name__ == "__main__":
    main()
