#!/usr/bin/env bash
# Install, update or remove the cosmic-desktop-extras tools for the current user.
#
#   ./install.sh                         interactive menu, recommended tools preselected
#   ./install.sh taskbar ws-keeper ...   install the named tools
#   ./install.sh all                     install every tool
#   ./install.sh --list                  tools, what they do, installed or not
#   ./install.sh --uninstall <tool...>   remove those tools, back to stock COSMIC
#   ./install.sh --update                git pull, then re-install / rebuild every installed tool
#   ./install.sh --dry-run <...>         print what would happen, change nothing
#
# One-line install without a clone (clones to ~/.local/share/cosmic-desktop-extras, then runs from there):
#   curl -fsSL https://raw.githubusercontent.com/jwillmer/cosmic-desktop-extras/main/install.sh | bash
#
# Everything goes into your home directory (~/.local, ~/.config, user systemd units). The only
# system change is an optional `sudo apt install` of build packages, and only after you agree.
# The installed tools link into this folder, so keep it; update with ./install.sh --update.
set -euo pipefail

REPO_URL=https://github.com/jwillmer/cosmic-desktop-extras.git
REPO_SLUG=jwillmer/cosmic-desktop-extras
CLONE="${XDG_DATA_HOME:-$HOME/.local/share}/cosmic-desktop-extras"

say() { printf '%s\n' "$*"; }
warn() { printf 'Note: %s\n' "$*" >&2; }
die() { printf 'Error: %s\n' "$*" >&2; exit 1; }

# A terminal to ask on: /dev/tty, so it also works under `curl ... | bash`. INSTALL_NO_TTY=1 (tests)
# behaves as if there were none.
have_tty() { [[ -z "${INSTALL_NO_TTY:-}" ]] && { : </dev/tty; } 2>/dev/null; }
ask_yes() {   # ask_yes <question>: true on y/yes
  local a
  printf '%s [y/N] ' "$1" >/dev/tty
  read -r a </dev/tty || return 1
  [[ "$a" =~ ^[Yy]([Ee][Ss])?$ ]]
}

# --- Bootstrap: not running from a clone (curl | bash) -> clone or pull, run the clone's copy ----------
download() {   # download <dir>: clone the repository into <dir>
  mkdir -p "$(dirname "$1")"
  if ! GIT_TERMINAL_PROMPT=0 git clone -q "$REPO_URL" "$1"; then
    # While the repository is private, a plain clone fails; an authenticated GitHub CLI can still clone it.
    if command -v gh >/dev/null && gh auth status >/dev/null 2>&1; then
      say "Trying again with the GitHub CLI (gh) ..."
      gh repo clone "$REPO_SLUG" "$1" -- -q || die "gh could not clone $REPO_SLUG."
    else
      die "could not download $REPO_URL.
Check your internet connection. If the repository is private, sign in to the GitHub CLI first
(gh auth login) and run this again, or clone it yourself and run ./install.sh from the clone."
    fi
  fi
}

SELF="${BASH_SOURCE[0]:-}"
if [[ -z "$SELF" || ! -f "$SELF" || ! -f "$(dirname "$SELF")/lib/patchset.sh" ]]; then
  command -v git >/dev/null || die "git is needed to download cosmic-desktop-extras. Install it with:
  sudo apt install git"
  dry=; for a in "$@"; do [[ "$a" == --dry-run || "$a" == -n ]] && dry=1; done
  if [[ -d "$CLONE/.git" ]]; then
    if [[ -n "$dry" ]]; then
      say "Dry run: would update $CLONE (git pull)."
    else
      say "Updating $CLONE ..."
      git -C "$CLONE" pull -q --ff-only ||
        warn "could not update $CLONE (offline or local changes?); going on with the copy that is there."
    fi
  elif [[ -n "$dry" ]]; then
    # A dry run changes nothing in your home: show the plan from a temporary copy, then delete it.
    say "Dry run: would download cosmic-desktop-extras to $CLONE. Showing the plan from a temporary copy."
    tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
    download "$tmp/cosmic-desktop-extras"
    bash "$tmp/cosmic-desktop-extras/install.sh" "$@"
    exit
  else
    say "Downloading cosmic-desktop-extras to $CLONE ..."
    download "$CLONE"
  fi
  exec bash "$CLONE/install.sh" "$@"
fi
R="$(cd "$(dirname "$SELF")" && pwd)"

# --- The tools ----------------------------------------------------------------------------------------
TOOLS=(taskbar terminal-tabs files-tabs tray-colors text-editor ws-keeper show-desktop)
RECOMMENDED=" taskbar ws-keeper show-desktop "
declare -A DESC=(
  [taskbar]="Taskbar for the windows of the current workspace (replaces the Minimized Windows applet)"
  [terminal-tabs]="Taskbar add-on: COSMIC Terminal windows show their tab count"
  [files-tabs]="Taskbar add-on: COSMIC Files windows show their tab or item count"
  [tray-colors]="Tray icons keep their own colours instead of the theme colour"
  [text-editor]="COSMIC Text Editor: Markdown preview, one window, session restore, change history"
  [ws-keeper]="Puts windows back on their workspaces after login or a compositor crash"
  [show-desktop]="Super+D minimizes the windows of the current workspace, again brings them back"
)
# Patched COSMIC apps: tool -> apt package whose exact upstream commit is rebuilt with our patches.
declare -A PACKAGE=([taskbar]=cosmic-applets [terminal-tabs]=cosmic-term [files-tabs]=cosmic-files [tray-colors]=cosmic-applets [text-editor]=cosmic-edit)
# The file whose presence means "installed" (internal names kept from earlier releases).
declare -A MARKER=(
  [taskbar]="$HOME/.local/bin/cosmic-applet-minimize-ws"
  [terminal-tabs]="$HOME/.local/bin/cosmic-term-tabs"
  [files-tabs]="$HOME/.local/bin/cosmic-files-tabs"
  [tray-colors]="$HOME/.local/bin/cosmic-applet-status-area-color"
  [text-editor]="$HOME/.local/bin/cosmic-edit-md"
  [ws-keeper]="$HOME/.local/bin/ws-keeper"
  [show-desktop]="$HOME/.local/bin/show-desktop"
)
# apt packages a cargo build of the COSMIC apps needs (cc for the -sys crates, headers for pkg-config).
BUILD_PKGS=(build-essential git pkg-config libxkbcommon-dev libfontconfig-dev libfreetype-dev libwayland-dev)
declare -A EXTRA_PKGS=([files-tabs]=libglib2.0-dev)

is_tool() { [[ " ${TOOLS[*]} " == *" $1 "* ]]; }
is_installed() { [[ -e "${MARKER[$1]}" ]]; }
is_patched() { [[ -n "${PACKAGE[$1]:-}" ]]; }
installed_tools() { local t; for t in "${TOOLS[@]}"; do is_installed "$t" && printf '%s ' "$t"; done; return 0; }

SYSTEMD_USER="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"
SHORTCUTS="${XDG_CONFIG_HOME:-$HOME/.config}/cosmic/com.system76.CosmicSettings.Shortcuts/v1/custom"

usage() {
  cat <<EOF
Usage:
  ./install.sh                         choose tools from a menu
  ./install.sh <tool...> | all         install those tools
  ./install.sh --list                  show the tools and whether they are installed
  ./install.sh --uninstall <tool...>   remove those tools (or: all)
  ./install.sh --update                update this folder (git pull), then rebuild every installed tool
  ./install.sh --dry-run <...>         show what would happen, change nothing

Tools: ${TOOLS[*]}
EOF
}

# --- Dry-run aware helpers ----------------------------------------------------------------------------
DRY=
run() { if [[ -n "$DRY" ]]; then say "  would run: $*"; else "$@"; fi; }
write_wrapper() {   # write_wrapper <name> <script in ~/.local/lib>
  mkdir -p "$HOME/.local/bin"
  # shellcheck disable=SC2016  # $HOME and $@ expand when the wrapper runs
  printf '#!/bin/sh\nexec python3 -I "$HOME/.local/lib/%s" "$@"\n' "$2" > "$HOME/.local/bin/$1"
  chmod 755 "$HOME/.local/bin/$1"
}
link_dir() {   # link_dir <folder> <name>: ~/.local/lib/<name> -> <folder>
  local l="$HOME/.local/lib/$2"
  mkdir -p "$HOME/.local/lib"
  if [[ -L "$l" ]]; then rm -f "$l"
  elif [[ -e "$l" ]]; then die "$l is a real folder, not a link this installer made. Move it away, then run ./install.sh again."
  fi
  ln -s "$1" "$l"
}
copy_units() { mkdir -p "$SYSTEMD_USER"; cp "$@" "$SYSTEMD_USER/"; }
remove_units() {   # remove_units <unit...>: disable, stop and delete user units
  systemctl --user disable --now "$@" 2>/dev/null || true
  local u; for u in "$@"; do rm -f "$SYSTEMD_USER/$u"; done
  systemctl --user daemon-reload 2>/dev/null || true
}
session_active() { systemctl --user -q is-active graphical-session.target 2>/dev/null; }

# --- Preflight ----------------------------------------------------------------------------------------
missing_pkgs() {   # missing_pkgs <pkg...>: those not installed
  local p
  for p in "$@"; do
    [[ "$(dpkg-query -W -f='${Status}' "$p" 2>/dev/null)" == "install ok installed" ]] || printf '%s ' "$p"
  done
  return 0
}

# Offer a fix: print the command; on a terminal ask and run it; without one (or on no) stop.
offer() {   # offer <what is missing> <command as shown> <command...>
  local what="$1" shown="$2"; shift 2
  say ""
  say "Missing: $what"
  say "Install it with:"
  say "  $shown"
  if [[ -n "$DRY" ]]; then say "  (dry run: would ask before installing)"; return 0; fi
  if have_tty && ask_yes "Install now?"; then
    "$@" || die "that did not work; run the command above yourself, then ./install.sh again."
  else
    die "run the command above, then ./install.sh again."
  fi
}

preflight() {   # preflight <tool...>
  local t need_build='' pkgs=() commit version
  if [[ "${XDG_CURRENT_DESKTOP:-}" != *COSMIC* ]]; then
    warn "this is not a COSMIC session (XDG_CURRENT_DESKTOP=${XDG_CURRENT_DESKTOP:-unset}). The tools are made
      for the COSMIC desktop (Pop!_OS 24.04); they take effect at your next COSMIC login."
  fi
  command -v python3 >/dev/null || offer "python3" "sudo apt install python3" sudo apt install -y python3
  for t in "$@"; do
    is_patched "$t" || continue
    need_build=1
    command -v dpkg-query >/dev/null || die "$t needs a Debian-based system with COSMIC from apt (Pop!_OS 24.04)."
    version="$(dpkg-query -W -f='${Version}' "${PACKAGE[$t]}" 2>/dev/null || true)"
    [[ -n "$version" ]] || die "$t patches the COSMIC package ${PACKAGE[$t]}, which is not installed.
       Install COSMIC first (Pop!_OS 24.04 ships it)."
    commit="${version##*~}"
    # Pop!_OS versions end in ~<upstream commit>, e.g. 1.0.0~1793636322~24.04~6f89bfa; the patches
    # are applied to exactly that commit so the result matches the rest of your desktop.
    [[ "$version" == *~* && "$commit" =~ ^[0-9a-f]{7,40}$ ]] || die "$t needs the Pop!_OS build of ${PACKAGE[$t]}
       (version ending in ~<git commit>), found version $version. Other builds are not supported yet."
    [[ -z "${EXTRA_PKGS[$t]:-}" ]] || pkgs+=("${EXTRA_PKGS[$t]}")
  done
  [[ -n "$need_build" ]] || return 0
  local miss
  miss="$(missing_pkgs "${BUILD_PKGS[@]}" "${pkgs[@]}")"
  if [[ -n "$miss" ]]; then
    # shellcheck disable=SC2086  # word splitting of the package list is wanted
    offer "build packages: $miss" "sudo apt install ${miss% }" sudo apt install -y $miss
  fi
  export PATH="$HOME/.cargo/bin:$PATH"
  if ! command -v cargo >/dev/null; then
    command -v curl >/dev/null || offer "curl (to download Rust)" "sudo apt install curl" sudo apt install -y curl
    offer "the Rust toolchain (cargo), installed into ~/.cargo for your user only" \
      "curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --profile minimal --no-modify-path" \
      bash -c "curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --profile minimal --no-modify-path"
    [[ -n "$DRY" ]] || command -v cargo >/dev/null || die "cargo is still not found in ~/.cargo/bin."
  fi
  say "The first build of a patched COSMIC app downloads and compiles its sources: several minutes each."
}

# --- Per-tool install / uninstall ---------------------------------------------------------------------
# The daily update check (minimize-ws-check.timer) covers every patched tool that is built.
install_check_timer() {
  run link_dir "$R/taskbar" minimize-ws
  run copy_units "$R/taskbar/systemd/minimize-ws-check.service" "$R/taskbar/systemd/minimize-ws-check.timer"
  run systemctl --user daemon-reload
  run systemctl --user enable --now minimize-ws-check.timer
}
remove_check_timer_if_unused() {
  local t
  for t in "${TOOLS[@]}"; do is_patched "$t" && is_installed "$t" && return 0; done
  [[ -n "$DRY" ]] && return 0
  remove_units minimize-ws-check.timer minimize-ws-check.service
  rm -f "$HOME/.local/lib/minimize-ws"
}

install_tool() {
  local t="$1"
  say ""
  say "== $t"
  case "$t" in
    taskbar|terminal-tabs|files-tabs|tray-colors|text-editor)
      run "$R/$t/build.sh"
      ;;
    ws-keeper)
      run link_dir "$R/ws-keeper" ws-keeper
      run write_wrapper ws-keeper ws-keeper/ws-keeper.py
      run copy_units "$R"/ws-keeper/systemd/*.service
      run systemctl --user daemon-reload
      run systemctl --user enable ws-keeper-restore.service ws-keeper-watch.service
      # Restart so a running watcher picks up new code; outside a desktop session it starts at login.
      if session_active; then run systemctl --user restart ws-keeper-watch.service; fi
      ;;
    show-desktop)
      run link_dir "$R/show-desktop" show-desktop
      run write_wrapper show-desktop show-desktop/show-desktop.py
      if grep -q 'show-desktop' "$SHORTCUTS" 2>/dev/null; then
        say "Super+D shortcut already set up."
      else
        run add_shortcut
      fi
      ;;
  esac
}

add_shortcut() {
  mkdir -p "$(dirname "$SHORTCUTS")"; [[ -s "$SHORTCUTS" ]] || echo '{}' > "$SHORTCUTS"
  local rc=0
  python3 -I - "$SHORTCUTS" "$HOME/.local/bin/show-desktop" <<'PY' || rc=$?
import re, sys
path, cmd = sys.argv[1], sys.argv[2]
s = open(path, encoding="utf-8").read()
# Another custom shortcut on Super+D: keep it, add none.
for mods, key in re.findall(r'\(\s*modifiers:\s*\[([^\]]*)\],\s*key:\s*"([^"]*)"', s):
    if [m for m in re.split(r'[\s,]+', mods) if m] == ["Super"] and key.lower() == "d":
        sys.exit(3)
s = s.rstrip()
if not s.endswith("}"):
    sys.exit(4)
def ron(v):
    return '"' + v.replace("\\", "\\\\").replace('"', '\\"') + '"'
entry = ("    (\n        modifiers: [\n            Super,\n        ],\n        key: \"d\",\n"
         "        description: Some(" + ron("Show desktop, as Win+D on Windows (cosmic-desktop-extras)") + "),\n"
         "    ): Spawn(" + ron(cmd) + "),\n}\n")
# Replace the file's last closing brace with the new entry plus the brace.
s = s[:-1].rstrip()
s = s + ("\n" if s.endswith(",") or s == "{" else ",\n") + entry
open(path, "w", encoding="utf-8").write(s)
PY
  case "$rc" in
    0) ;;
    3) warn "another custom shortcut already uses Super+D: kept it and added none. Bind
      $HOME/.local/bin/show-desktop yourself in Settings > Keyboard > Custom shortcuts." ;;
    4) warn "could not read $SHORTCUTS (no closing \"}\"): added no Super+D shortcut. Bind
      $HOME/.local/bin/show-desktop yourself in Settings > Keyboard > Custom shortcuts." ;;
    *) return "$rc" ;;
  esac
}

remove_shortcut() {   # drop the entry that spawns ~/.local/bin/show-desktop, keep every other shortcut
  [[ -f "$SHORTCUTS" ]] || return 0
  python3 -I - "$SHORTCUTS" <<'EOF'
import re, sys
p = sys.argv[1]
s = open(p).read()
q = r'"(?:[^"\\]|\\.)*'   # start of a RON string, escapes allowed
t = re.sub(r'[ \t]*\(\s*modifiers:\s*\[[^\]]*\],\s*key:\s*"[^"]*",\s*(?:description:\s*Some\(' + q + r'"\),?\s*)?\):\s*Spawn\(' + q
           + r'/\.local/bin/show-desktop"\),?[ \t]*\n?', "", s)
if t != s:
    open(p, "w").write(t)
EOF
}

uninstall_tool() {
  local t="$1"
  say ""
  say "== $t: removing"
  case "$t" in
    taskbar|terminal-tabs|files-tabs|tray-colors|text-editor)
      run "$R/$t/build.sh" --uninstall
      # check.sh treats a recorded build as installed; the other build.sh scripts remove theirs.
      [[ "$t" == taskbar ]] && run rm -f "${XDG_STATE_HOME:-$HOME/.local/state}/minimize-ws/built-commit"
      remove_check_timer_if_unused
      [[ "$t" == taskbar ]] && say "Kept your taskbar settings in ${XDG_CONFIG_HOME:-$HOME/.config}/minimize-ws (delete by hand if unwanted)."
      ;;
    ws-keeper)
      run remove_units ws-keeper-watch.service ws-keeper-restore.service
      run rm -f "$HOME/.local/bin/ws-keeper" "$HOME/.local/lib/ws-keeper"
      say "Kept your window snapshots in ${XDG_STATE_HOME:-$HOME/.local/state}/ws-keeper (delete by hand if unwanted)."
      ;;
    show-desktop)
      run remove_shortcut
      run rm -f "$HOME/.local/bin/show-desktop" "$HOME/.local/lib/show-desktop"
      say "Removed the Super+D shortcut. Kept ${XDG_STATE_HOME:-$HOME/.local/state}/show-desktop."
      ;;
  esac
  return 0
}

# --- Panel check (read only) --------------------------------------------------------------------------
# The patched applets take over the desktop entry ids of the stock ones, so they show only where the
# stock applet is on a panel. COSMIC reads ~/.config/cosmic/... and falls back to /usr/share/cosmic/...
panels_with() {   # panels_with <applet id>: names of the panels / docks that have it
  local user="${XDG_CONFIG_HOME:-$HOME/.config}/cosmic" sys="${COSMIC_SYSTEM_CONFIG:-/usr/share/cosmic}"
  local entries name f found=()
  entries="$(cat "$user/com.system76.CosmicPanel/v1/entries" 2>/dev/null || cat "$sys/com.system76.CosmicPanel/v1/entries" 2>/dev/null || true)"
  for name in $(grep -o '"[^"]*"' <<<"$entries" | tr -d '"'); do
    for f in plugins_wings plugins_center; do
      local file="$user/com.system76.CosmicPanel.$name/v1/$f"
      [[ -f "$file" ]] || file="$sys/com.system76.CosmicPanel.$name/v1/$f"
      if grep -qF "\"$1\"" "$file" 2>/dev/null; then found+=("$name"); break; fi
    done
  done
  printf '%s' "${found[*]:-}"
}

next_steps() {   # next_steps <tool>
  local p
  case "$1" in
    taskbar)
      p="$(panels_with com.system76.CosmicAppletMinimize)"
      if [[ -n "$p" ]]; then say "  taskbar: replaced the \"Minimized Windows\" applet on your $p."
      else say "  taskbar: the \"Minimized Windows\" applet is not on any panel, so the taskbar does not show yet."
           say "           Add it: Settings > Desktop > Panel (or Dock) > Configure panel applets > Add applet > Minimized Windows."
      fi ;;
    tray-colors)
      p="$(panels_with com.system76.CosmicAppletStatusArea)"
      if [[ -n "$p" ]]; then say "  tray-colors: the tray (Notifications Tray applet) on your $p keeps icon colours now."
      else say "  tray-colors: add the \"Notifications Tray\" applet in Settings > Desktop > Panel to see it."
      fi ;;
    terminal-tabs) say "  terminal-tabs: close and reopen terminal windows; the taskbar then shows their tab count." ;;
    files-tabs) say "  files-tabs: close and reopen file manager windows; the taskbar then shows their tabs or items." ;;
    text-editor) say "  text-editor: close and reopen the Text Editor; Markdown files then open rendered (Ctrl+Shift+V switches)." ;;
    ws-keeper) say "  ws-keeper: runs in the background and restores window workspaces at login (ws-keeper list shows them)." ;;
    show-desktop) say "  show-desktop: press Super+D (change it in Settings > Keyboard > Custom shortcuts)." ;;
  esac
}

# --- Commands -----------------------------------------------------------------------------------------
cmd_list() {
  local t state rec
  printf '%-16s %-10s %s\n' TOOL INSTALLED DESCRIPTION
  for t in "${TOOLS[@]}"; do
    state=no; is_installed "$t" && state=yes
    rec=; [[ "$RECOMMENDED" == *" $t "* ]] && rec=" (recommended)"
    printf '%-16s %-10s %s%s\n' "$t" "$state" "${DESC[$t]}" "$rec"
  done
}

menu() {   # prints the chosen tools; reads the answers from /dev/tty
  local -A sel=() ; local t i a n
  for t in "${TOOLS[@]}"; do
    [[ "$RECOMMENDED" == *" $t "* ]] || is_installed "$t" && sel[$t]=1
  done
  while true; do
    {
      echo ""
      echo "cosmic-desktop-extras: choose the tools to install"
      i=0
      for t in "${TOOLS[@]}"; do
        i=$((i + 1))
        local mark=" "; [[ -n "${sel[$t]:-}" ]] && mark=x
        local inst=""; is_installed "$t" && inst=" [installed]"
        printf '  %d) [%s] %-16s %s%s\n' "$i" "$mark" "$t" "${DESC[$t]}" "$inst"
      done
      echo ""
      printf 'Numbers to toggle (e.g. 2 3), a = all, Enter = install the marked ones, q = quit: '
    } >/dev/tty
    read -r a </dev/tty || exit 1
    case "$a" in
      "") break ;;
      q|Q) echo "Nothing installed." >/dev/tty; exit 0 ;;
      a|A) for t in "${TOOLS[@]}"; do sel[$t]=1; done ;;
      *) for n in $a; do
           if [[ "$n" =~ ^[0-9]+$ ]] && (( n >= 1 && n <= ${#TOOLS[@]} )); then
             t="${TOOLS[$((n - 1))]}"
             if [[ -n "${sel[$t]:-}" ]]; then unset "sel[$t]"; else sel[$t]=1; fi
           else echo "Unknown choice: $n" >/dev/tty; fi
         done ;;
    esac
  done
  for t in "${TOOLS[@]}"; do [[ -n "${sel[$t]:-}" ]] && printf '%s ' "$t"; done
  return 0
}

check_names() { local a; for a in "$@"; do [[ "$a" == all ]] || is_tool "$a" || die "unknown tool \"$a\". Tools: ${TOOLS[*]} (or all)."; done; }
ordered() {   # ordered <tool...>: unique, in TOOLS order; "all" expands (names checked by check_names)
  local t a
  for t in "${TOOLS[@]}"; do
    for a in "$@"; do
      if [[ "$a" == all || "$a" == "$t" ]]; then printf '%s ' "$t"; break; fi
    done
  done
}

cmd_install() {
  local tools=("$@") t
  [[ ${#tools[@]} -gt 0 ]] || { say "No tools chosen."; return 0; }
  [[ -n "$DRY" ]] && say "Dry run: nothing is changed."
  say "Installing: ${tools[*]}"
  for t in terminal-tabs files-tabs; do
    if [[ " ${tools[*]} " == *" $t "* && " ${tools[*]} " != *" taskbar "* ]] && ! is_installed taskbar; then
      warn "$t is a taskbar add-on: it changes nothing visible without the taskbar."
    fi
  done
  preflight "${tools[@]}"
  local ok=() failed=() rc patched=''
  for t in "${tools[@]}"; do
    # Each tool in its own subshell with set -e, so one failed build does not stop the others.
    set +e; ( set -e; install_tool "$t" ); rc=$?; set -e
    if [[ $rc -eq 0 ]]; then ok+=("$t"); if is_patched "$t"; then patched=1; fi
    else failed+=("$t"); say "!! $t failed (exit $rc); going on with the others."; fi
  done
  if [[ -n "$patched" ]]; then
    say ""; say "== daily update check (minimize-ws-check.timer)"
    set +e; ( set -e; install_check_timer ); rc=$?; set -e
    [[ $rc -eq 0 ]] || { failed+=("update-check"); say "!! the daily update check could not be installed."; }
  fi
  say ""
  if [[ -n "$DRY" ]]; then say "Dry run done: nothing was changed."; return 0; fi
  say "Summary:"
  for t in "${ok[@]}"; do say "  OK      $t"; done
  for t in "${failed[@]}"; do say "  FAILED  $t"; done
  if [[ ${#ok[@]} -gt 0 ]]; then
    say "Next:"
    for t in "${ok[@]}"; do next_steps "$t"; done
    say ""
    say "The tools run from $R: keep that folder. Update later with: $R/install.sh --update"
  fi
  if [[ ${#failed[@]} -gt 0 ]]; then
    say ""
    say "Some parts failed: read the messages above, fix the cause, then run ./install.sh again with those tools."
    return 1
  fi
}

cmd_uninstall() {
  local tools=("$@") t
  [[ ${#tools[@]} -gt 0 ]] || die "name the tools to remove, e.g. ./install.sh --uninstall taskbar (or all)."
  [[ -n "$DRY" ]] && say "Dry run: nothing is changed."
  for t in "${tools[@]}"; do
    if is_installed "$t"; then uninstall_tool "$t"; else say ""; say "== $t: not installed, cleaning up leftovers"; uninstall_tool "$t"; fi
  done
  say ""
  if [[ -n "$DRY" ]]; then say "Dry run done: nothing was changed."; return 0; fi
  say "Removed: ${tools[*]}. COSMIC uses its own versions again."
}

cmd_update() {
  local tools
  tools="$(installed_tools)"
  [[ -d "$R/.git" ]] || die "$R is not a git clone, so it cannot update itself. Download it again with:
  curl -fsSL https://raw.githubusercontent.com/$REPO_SLUG/main/install.sh | bash"
  if [[ -n "$DRY" ]]; then
    say "Dry run: would run git -C $R pull --ff-only, then rebuild / re-install: ${tools:-nothing (no tool installed)}"
    # shellcheck disable=SC2086  # one argument per tool
    [[ -z "$tools" ]] || exec "$R/install.sh" --dry-run $tools
    return 0
  fi
  say "Updating $R ..."
  git -C "$R" pull -q --ff-only || die "git pull failed (local changes?). Check it with: git -C $R status"
  [[ -n "$tools" ]] || { say "Up to date. No tool is installed yet: ./install.sh to choose."; return 0; }
  # Re-run the updated installer, which may differ from this one.
  # shellcheck disable=SC2086  # one argument per tool
  exec "$R/install.sh" $tools
}

# --- Main ---------------------------------------------------------------------------------------------
mode=install args=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run|-n) DRY=1 ;;
    --list|-l) mode=list ;;
    --uninstall|--remove) mode=uninstall ;;
    --update|-u) mode=update ;;
    -h|--help) usage; exit 0 ;;
    -*) usage >&2; die "unknown option $1" ;;
    *) args+=("$1") ;;
  esac
  shift
done

check_names "${args[@]}"
case "$mode" in
  list) cmd_list ;;
  update) cmd_update ;;
  uninstall)
    # shellcheck disable=SC2046  # one argument per tool
    cmd_uninstall $(ordered "${args[@]}") ;;
  install)
    if [[ ${#args[@]} -eq 0 ]]; then
      have_tty || { usage >&2; die "no terminal to show the menu on: name the tools, e.g. ./install.sh taskbar"; }
      chosen="$(menu)" || { echo "Cancelled: nothing installed." >&2; exit 1; }
      [[ -n "$chosen" ]] || exit 0   # q: nothing chosen
      # shellcheck disable=SC2086  # one argument per tool
      set -- $chosen
    else
      # shellcheck disable=SC2046
      set -- $(ordered "${args[@]}")
    fi
    cmd_install "$@" ;;
esac
