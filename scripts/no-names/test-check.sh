#!/usr/bin/env bash
# Runs check.py against small repositories built here, one case per change, and prints PASS or FAIL for each.
set -u
here=$(cd "$(dirname "$0")" && pwd)
check="${CHECK:-$here/check.py}"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

# The team the cases check against, in the TEAM_MEMBERS shape. A case sets team_json to try another value, or
# unset_team=1 to run with TEAM_MEMBERS unset.
team_json='{"adalogin": {"slack": "U0123ABCD", "names": ["Ada", "Lovelace"]}, "ex-will": {"names": ["exact:Will"]}}'

failures=0
cases=0

# new_repo: a repository with one base commit; prints nothing.
new_repo() {
  rm -rf "$work/repo" && mkdir -p "$work/repo/.github/workflows" "$work/repo/src" && cd "$work/repo" || exit 1
  git init -q -b dev . && git config user.email t@example.com && git config user.name tester
  printf 'const a = 1;\n// Ada wrote this long ago\n' > src/a.ts
  printf 'case "$login" in\nesac\n' > .github/workflows/deploy-dev.yml
  git add -A && git commit -q -m "base" && git branch base
}

# expect <name> <pass|fail> <text the output must contain>: runs the check on base..HEAD.
expect() {
  cases=$((cases + 1))
  if [ "${unset_team:-0}" = 1 ]; then
    out=$(cd "$work/repo" && env -u TEAM_MEMBERS python3 "$check" --base base --head HEAD 2>&1)
  else
    out=$(cd "$work/repo" && TEAM_MEMBERS="$team_json" python3 "$check" --base base --head HEAD 2>&1)
  fi
  rc=$?
  want_rc=0; [ "$2" = fail ] && want_rc=1
  if [ "$rc" = "$want_rc" ] && printf '%s' "$out" | grep -q -F -- "$3"; then
    echo "PASS $1"
  else
    echo "FAIL $1 (rc=$rc, wanted $want_rc and \"$3\")"; printf '%s\n' "$out" | sed 's/^/    /'
    failures=$((failures + 1))
  fi
}

commit() { git add -A && git commit -q -m "$1"; }

new_repo; printf 'const b = 2;\n' >> src/a.ts; commit "add b"
PR_TITLE="chore: add b" PR_BODY="Adds b." expect "a clean change passes" pass "no names"

new_repo; printf '// per Ada, keep this\n' >> src/a.ts; commit "add note"
PR_TITLE="t" PR_BODY="b" expect "a name on an added line fails, with its file and line" fail "src/a.ts:3: // per Ada, keep this"

new_repo; printf 'const c = 3;\n// Will again\n' >> src/a.ts; commit "add c"
PR_TITLE="t" PR_BODY="b" expect "a name on the second added line of a hunk names that line" fail "src/a.ts:4: // Will again"

new_repo; printf '++ marker\nhello Ada\n' >> src/a.ts; commit "quote a diff"
PR_TITLE="t" PR_BODY="b" expect "an added line starting with ++ does not hide the lines after it" fail "src/a.ts:4: hello Ada"

new_repo; printf -- '-- old\n' > notes.md; commit "notes"; git branch -f base; printf 'new\nhello Ada\n' > notes.md; commit "rewrite"
PR_TITLE="t" PR_BODY="b" expect "a removed line starting with -- does not hide the added lines" fail "notes.md:2: hello Ada"

new_repo; printf 'const r = "a\r+b";\nhello Ada\n' >> src/a.ts; commit "carriage return"
PR_TITLE="t" PR_BODY="b" expect "a carriage return inside a line does not hide the next line" fail "src/a.ts:4: hello Ada"

new_repo; printf 'const a = 2; // ada\n// Ada wrote this long ago\n' > src/a.ts; commit "one line replaced"
PR_TITLE="t" PR_BODY="b" expect "a one-line hunk with no counts in its header is read" fail "src/a.ts:1:"

new_repo; printf '{ code: "WILL" } // the user will see it\n' >> src/a.ts; commit "region"
PR_TITLE="t" PR_BODY="b" expect "an exact-case name in another case passes" pass "no names"

new_repo; printf 'const e = "ada@example.com";\n' >> src/a.ts; commit "add e"
PR_TITLE="t" PR_BODY="b" expect "a lowercase name in an email fails" fail "src/a.ts:3:"

new_repo; printf 'const ADALOGIN = 1;\n' >> src/a.ts; commit "add const"
PR_TITLE="t" PR_BODY="b" expect "a login in another letter case fails" fail "src/a.ts:3:"

new_repo; printf 'const tomato = "Adaptive, Tomcat";\n' >> src/a.ts; commit "add tomato"
PR_TITLE="t" PR_BODY="b" expect "a name inside a longer word passes" pass "no names"

new_repo; printf '            "adalogin") name="<@U0000>" ;;\n' >> .github/workflows/deploy-dev.yml; commit "map"
PR_TITLE="t" PR_BODY="b" expect "the deploy Slack map line passes" pass "no names"

new_repo; printf '# reviewed by Ada\n' >> .github/workflows/deploy-dev.yml; commit "note"
PR_TITLE="t" PR_BODY="b" expect "a workflow line outside the Slack map fails" fail ".github/workflows/deploy-dev.yml:3:"

new_repo; printf 'const n = { name="Ada" };\n' >> src/a.ts; commit "name"
PR_TITLE="t" PR_BODY="b" expect "a name=\" line outside the workflows fails" fail "src/a.ts:3:"

new_repo; printf 'const a = 1;\n' > src/a.ts; commit "drop the note"
PR_TITLE="t" PR_BODY="b" expect "a name on a removed line passes" pass "no names"

new_repo; printf '"integrity": "sha512-x+Will/y=="\n' > package-lock.json; commit "lock"
PR_TITLE="t" PR_BODY="b" expect "a lock file line passes" pass "no names"

new_repo; printf 'const b = 2;\n' >> src/a.ts; commit "add b"
PR_TITLE="chore: what Will asked" PR_BODY="b" expect "a name in the title fails" fail "title: chore: what Will asked"

new_repo; printf 'const b = 2;\n' >> src/a.ts; commit "add b"
PR_TITLE="t" PR_BODY=$'Closes #1\n\nAs Ada asked.' expect "a name in the description fails, with its line" fail "description:3: As Ada asked."

new_repo; printf 'const b = 2;\n' >> src/a.ts; commit $'add b\n\nAda asked for it.'
PR_TITLE="t" PR_BODY="b" expect "a name in a commit message fails" fail "commit "

new_repo; printf 'const b = 2;\n' >> src/a.ts; commit "add b"
PR_TITLE="t" PR_BODY=$'Closes #1\n\n@AdaLogin please review' expect "a description line addressing someone by @login passes" pass "no names"
team_json='{"AdaLogin": {"names": ["Ada"]}}' PR_TITLE="t" PR_BODY="@adalogin please review" expect "an @login matches a login written in another case" pass "no names"
PR_TITLE="t" PR_BODY="thanks Ada (@adalogin)" expect "a description line with an @login and a name fails" fail "description:1: thanks Ada (@adalogin)"
PR_TITLE="t" PR_BODY="@Ada please review" expect "a name written as an @mention fails" fail "description:1: @Ada please review"
PR_TITLE="t" PR_BODY="write to ada@example.com" expect "an email in the description fails" fail "description:1: write to ada@example.com"
PR_TITLE="t" PR_BODY="write to ops@adalogin.dev" expect "an address at a login's domain fails" fail "description:1: write to ops@adalogin.dev"
PR_TITLE="chore: for @adalogin" PR_BODY="b" expect "an @login in the title fails" fail "title: chore: for @adalogin"

new_repo; printf 'const b = 2;\n' >> src/a.ts; commit $'add b\n\nfor @adalogin'
PR_TITLE="t" PR_BODY="b" expect "an @login in a commit message fails" fail ":3: for @adalogin"

new_repo; printf '// ask @adalogin\n' >> src/a.ts; commit "add note"
PR_TITLE="t" PR_BODY="b" expect "an @login on an added line fails" fail "src/a.ts:3: // ask @adalogin"

new_repo; printf 'const b = 2;\n' >> src/a.ts; commit "add b"; git mv src/a.ts "src/a b.ts" && printf 'const ada = 3;\n' >> "src/a b.ts"; commit "move"
PR_TITLE="t" PR_BODY="b" expect "a name in a file whose path has a space fails" fail "src/a b.ts:"

new_repo; printf '// paired with ex-will\n' >> src/a.ts; commit "login"
PR_TITLE="t" PR_BODY="b" expect "a login with a hyphen fails" fail "src/a.ts:3: // paired with ex-will"

new_repo; printf '// per adalogin\n' >> src/a.ts; commit "old shape"
team_json='{"adalogin": "U0123ABCD"}' PR_TITLE="t" PR_BODY="b" expect "an entry that is only a Slack member ID still refuses its login" fail "src/a.ts:3: // per adalogin"

new_repo; printf 'const b = 2;\n' >> src/a.ts; commit "add b"
unset_team=1 PR_TITLE="t" PR_BODY="b" expect "an unset TEAM_MEMBERS fails, checking nothing" fail "TEAM_MEMBERS is not JSON, so nothing can be checked"
team_json='{"adalogin": ' PR_TITLE="t" PR_BODY="b" expect "a TEAM_MEMBERS that is not JSON fails" fail "TEAM_MEMBERS is not JSON, so nothing can be checked"
team_json='["Ada"]' PR_TITLE="t" PR_BODY="b" expect "a TEAM_MEMBERS that is not an object fails" fail "TEAM_MEMBERS is not a JSON object of GitHub login to entry"
team_json='{}' PR_TITLE="t" PR_BODY="b" expect "an empty TEAM_MEMBERS fails" fail "TEAM_MEMBERS names nobody, so nothing can be checked"
team_json='{"adalogin": {"names": "Ada"}}' PR_TITLE="t" PR_BODY="b" expect "names that are not a list fail" fail "TEAM_MEMBERS: the names of adalogin are not a list"

expected=36
echo "cases=$cases failures=$failures expected=$expected"
[ "$failures" = 0 ] && [ "$cases" = "$expected" ]
