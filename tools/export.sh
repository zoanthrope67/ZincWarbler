#!/usr/bin/env bash
# Zinc Warbler: checks that the game compiles, then exports the Linux and
# Windows builds into build/.
#
# AS A GIT PRE-COMMIT HOOK (install it once, by hand, from the repo's top folder):
#     ln -s ../../tools/export.sh .git/hooks/pre-commit
# Every "git commit" then runs it first. If anything fails, the commit is
# stopped and the problem is printed. To commit anyway (e.g. work in progress):
#     git commit --no-verify
# To uninstall:
#     rm .git/hooks/pre-commit
#
# BY HAND (from anywhere in the repo):
#     tools/export.sh                  checks and exports what is staged for commit
#     tools/export.sh --working-tree   checks and exports src/ as it is on disk
#
# What it does:
#   1. Copies the project into a temporary folder. By default that is exactly
#      what is staged, i.e. what the commit will contain, so unstaged edits
#      cannot hide a broken commit. Working on a copy also means it never
#      touches the import cache of a Godot editor that is open on src/.
#   2. Imports the copy and loads every script, scene and resource in it
#      (tools/check_project.gd). Godot's export does NOT fail on script errors,
#      so this step is what catches them.
#   3. Exports the "Linux" and "Windows Desktop" presets from
#      src/export_presets.cfg. Only if everything worked are build/linux and
#      build/windows replaced with the new builds.
# Any "ERROR:" printed by Godot during these steps also counts as a failure.
#
# Needs the Godot binary in Godot_v4.7.2-stable_linux.x86_64/ (or set GODOT to
# its path) and Godot's 4.7.2 export templates (Editor > Manage Export Templates).
# Takes about 15 seconds.

set -euo pipefail

# --- Settings ---------------------------------------------------------------------

REPO_ROOT="$(git rev-parse --show-toplevel)"
# The Godot editor binary. Can be overridden: GODOT=/path/to/godot tools/export.sh
GODOT="${GODOT:-$REPO_ROOT/Godot_v4.7.2-stable_linux.x86_64/Godot_v4.7.2-stable_linux.x86_64}"
# Where the finished builds go (ignored by git).
BUILD_DIR="$REPO_ROOT/build"
# The script that loads everything to check it compiles.
CHECK_SCRIPT="$REPO_ROOT/tools/check_project.gd"
# Each export: "preset name in export_presets.cfg|folder in build/|file name".
EXPORTS=(
	"Linux|linux|ZincWarbler.x86_64"
	"Windows Desktop|windows|ZincWarbler.exe"
)
# Longest each Godot step may take, in seconds, before it counts as failed.
STEP_TIMEOUT_SECONDS=300

# --- Helpers -----------------------------------------------------------------------

# True when git is running this script as the pre-commit hook.
is_hook() {
	[[ "$(basename "$0")" == "pre-commit" ]]
}

say() {
	echo "[export] $*"
}

# Prints the problem and stops. As a hook, a non-zero exit stops the commit.
fail() {
	echo "[export] FAILED: $*" >&2
	if is_hook; then
		echo "[export] The commit was stopped. Fix the problem above, or commit anyway with: git commit --no-verify" >&2
	fi
	exit 1
}

# Runs Godot headless on the copied project. Its output goes into the log file
# given as the first argument. Returns Godot's exit code.
run_godot() {
	local log="$1"
	shift
	timeout "$STEP_TIMEOUT_SECONDS" "$GODOT" --headless \
		--log-file "$WORK_DIR/godot_internal.log" \
		--path "$PROJECT_DIR" "$@" >"$log" 2>&1
}

# Prints the last lines of a log, without Godot's colour codes.
show_log() {
	echo "----- last lines of the Godot output -----" >&2
	sed 's/\x1b\[[0-9;]*m//g' "$1" | tail -n 40 >&2
	echo "------------------------------------------" >&2
}

# Fails if Godot printed any error into the log, even if it still finished.
fail_on_logged_errors() {
	local log="$1" step="$2"
	if grep -q 'ERROR:' "$log"; then
		echo "[export] Godot reported errors during $step:" >&2
		sed 's/\x1b\[[0-9;]*m//g' "$log" | grep -A 3 'ERROR:' | head -n 40 >&2
		fail "$step reported errors."
	fi
}

# --- Options -----------------------------------------------------------------------

SOURCE="staged"
case "${1:-}" in
	"") ;;
	--working-tree) SOURCE="working-tree" ;;
	*)
		echo "Usage: tools/export.sh [--working-tree]" >&2
		exit 2
		;;
esac

# --- 1. Copy the project ------------------------------------------------------------

[[ -x "$GODOT" ]] || fail "Godot was not found at: $GODOT (set GODOT=/path/to/godot to use another copy)."
[[ -f "$CHECK_SCRIPT" ]] || fail "The check script was not found at: $CHECK_SCRIPT"

WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/zincwarbler-export.XXXXXX")"
# Always delete the temporary folder, whether this succeeds or fails.
trap 'rm -rf "$WORK_DIR"' EXIT
PROJECT_DIR="$WORK_DIR/src"

cd "$REPO_ROOT"
if [[ "$SOURCE" == "staged" ]]; then
	say "Copying the staged project..."
	# Writes the staged version of every file under src/ into the temporary
	# folder. This only reads from git; it changes nothing in the repo.
	git ls-files -z -- src | git checkout-index -z --stdin --prefix="$WORK_DIR/"
else
	say "Copying src/ as it is on disk..."
	# Everything except Godot's import cache, which the copy rebuilds itself.
	tar -C "$REPO_ROOT" --exclude='src/.godot' -cf - src | tar -C "$WORK_DIR" -xf -
fi
[[ -f "$PROJECT_DIR/project.godot" ]] || fail "src/project.godot is missing from the copied project."

# --- 2. Import and check ------------------------------------------------------------

say "Importing..."
run_godot "$WORK_DIR/import.log" --import || { show_log "$WORK_DIR/import.log"; fail "the import did not finish."; }
fail_on_logged_errors "$WORK_DIR/import.log" "the import"

say "Checking every script, scene and resource loads..."
if ! run_godot "$WORK_DIR/check.log" --script "$CHECK_SCRIPT"; then
	show_log "$WORK_DIR/check.log"
	fail "some files have errors (listed above)."
fi
fail_on_logged_errors "$WORK_DIR/check.log" "the check"

# --- 3. Export ----------------------------------------------------------------------

for export in "${EXPORTS[@]}"; do
	IFS='|' read -r preset folder file <<<"$export"
	say "Exporting \"$preset\"..."
	mkdir -p "$WORK_DIR/out/$folder"
	run_godot "$WORK_DIR/export_$folder.log" --export-release "$preset" "$WORK_DIR/out/$folder/$file" \
		|| { show_log "$WORK_DIR/export_$folder.log"; fail "the \"$preset\" export failed."; }
	fail_on_logged_errors "$WORK_DIR/export_$folder.log" "the \"$preset\" export"
done

# Everything worked: replace the old builds with the new ones.
mkdir -p "$BUILD_DIR"
for export in "${EXPORTS[@]}"; do
	IFS='|' read -r preset folder file <<<"$export"
	rm -rf "${BUILD_DIR:?}/$folder"
	mv "$WORK_DIR/out/$folder" "$BUILD_DIR/$folder"
	say "Built build/$folder/$file"
done

say "OK: the game compiles and both builds are up to date."
