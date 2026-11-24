#!/usr/bin/env zsh
emulate -R zsh
setopt err_exit no_unset pipe_fail

root=${0:A:h:h}
output_dir=${1:-$root/docs}
TESTS_DIR=$root/tests
GW_REPO=$root
source "$TESTS_DIR/helpers.zsh"

export TZ=UTC
now=$EPOCHSECONDS
sandbox=$(mktemp -d "${${TMPDIR:-/tmp}%/}/gw-render.XXXXXX")
trap 'rm -rf "$sandbox"' EXIT
sandbox_enter "$sandbox" > /dev/null
export GW_TEST_NOW=$now

utc() {
  strftime "$1" $(( now - $2 ))
}

given_sample_service() {
  local service=$1 commit=$2 deployed_ago=$3 started_ago=$4 person=$5
  shift 5
  given_remote_service "$service" "$commit" "$(utc '%Y%m%d%H%M' "$deployed_ago")"
  given_remote_unit "$service" "ActiveEnterTimestamp=$(utc '%a %Y-%m-%d %H:%M:%S UTC' "$started_ago")" "$@"
  [[ -n $person ]] || return 0
  print -l "name=$person" "commit=$commit" "version_mtime=$(stat -f %m "$GW_TEST_DIR/jrd/$service/version")" \
    > "$GW_TEST_DIR/jrd/$service/.gw-deployed-by"
}

render_svg() {
  python3 - "$@" <<'PYTHON'
import html
import re
import sys
import unicodedata

COLORS = {
    "31": "#ff7b72", "32": "#3fb950", "33": "#d29922", "34": "#58a6ff",
    "35": "#d2a8ff", "36": "#39c5cf", "90": "#8b949e",
}
FOREGROUND, BACKGROUND, BORDER = "#e6edf3", "#0d1117", "#30363d"
FONT_SIZE, CHAR_WIDTH, LINE_HEIGHT, PADDING, TITLE_BAR = 13, 7.83, 20, 18, 30


def width(text):
    return sum(2 if unicodedata.east_asian_width(c) == "W" else 0 if unicodedata.category(c) == "Mn" or c == "\ufe0f" else 1 for c in text)


def segments(line):
    style = {"bold": False, "underline": False, "color": None}
    for part in re.split(r"(\x1b\[[0-9;]*[A-Za-z])", line):
        if part.startswith("\x1b["):
            if not part.endswith("m"):
                continue
            for code in (part[2:-1] or "0").split(";"):
                if code == "0":
                    style = {"bold": False, "underline": False, "color": None}
                elif code == "1":
                    style["bold"] = True
                elif code == "4":
                    style["underline"] = True
                elif code in COLORS:
                    style["color"] = COLORS[code]
        elif part:
            yield part, dict(style)


lines = open(sys.argv[1], encoding="utf-8").read().rstrip("\n").split("\n")
columns = max(width(re.sub(r"\x1b\[[0-9;]*[A-Za-z]", "", line)) for line in lines)
svg_width = round((columns + 2) * CHAR_WIDTH + 2 * PADDING)
svg_height = TITLE_BAR + len(lines) * LINE_HEIGHT + PADDING

out = [
    f'<svg xmlns="http://www.w3.org/2000/svg" width="{svg_width}" height="{svg_height}" viewBox="0 0 {svg_width} {svg_height}" role="img" aria-label="{html.escape(sys.argv[3])}">',
    f'<rect width="100%" height="100%" rx="8" fill="{BACKGROUND}" stroke="{BORDER}"/>',
    '<circle cx="18" cy="15" r="5" fill="#ff5f57"/><circle cx="36" cy="15" r="5" fill="#febc2e"/><circle cx="54" cy="15" r="5" fill="#28c840"/>',
    f'<g font-family="ui-monospace, SFMono-Regular, Menlo, Consolas, monospace" font-size="{FONT_SIZE}" fill="{FOREGROUND}" xml:space="preserve">',
]
BLOCKS = {"\u2588": 1.0, "\u2591": 0.35}


def tspan(column, text, style):
    attributes = [f'x="{PADDING + column * CHAR_WIDTH:.1f}"']
    if style["color"]:
        attributes.append(f'fill="{style["color"]}"')
    if style["bold"]:
        attributes.append('font-weight="bold"')
    if style["underline"]:
        attributes.append('text-decoration="underline"')
    return f'<tspan {" ".join(attributes)}>{html.escape(text)}</tspan>'


def bar(column, length, character, style, y):
    return (
        f'<rect x="{PADDING + column * CHAR_WIDTH:.1f}" y="{y - FONT_SIZE + 2:.1f}" '
        f'width="{length * CHAR_WIDTH:.2f}" height="{LINE_HEIGHT - 6}" '
        f'fill="{style["color"] or FOREGROUND}" fill-opacity="{BLOCKS[character]}"/>'
    )


for row, line in enumerate(lines):
    y = TITLE_BAR + PADDING / 2 + row * LINE_HEIGHT + FONT_SIZE
    column = 0
    spans, cells = [], []
    for text, style in segments(line):
        if style["underline"]:
            spans.append(tspan(column, text, style))
            column += width(text)
            continue
        for run in re.findall(r"\u2588+|\u2591+| +|[^ \u2588\u2591]+", text):
            if run[0] in BLOCKS:
                cells.append(bar(column, len(run), run[0], style, y))
            elif run[0] != " ":
                spans.append(tspan(column, run, style))
            column += width(run)
    out.extend(cells)
    if spans:
        out.append(f'<text y="{y:.1f}">{"".join(spans)}</text>')
out.append("</g></svg>")
open(sys.argv[2], "w", encoding="utf-8").write("\n".join(out) + "\n")
PYTHON
}

given_alias alpha td@alpha.local

given_sample_service rest-api a1b2c3d4e5f60718 200 185 'Adilet Baimyrza'
given_sample_service transceiver e5f6a7b8c9d00112 $(( 4 * 86400 + 2 * 3600 + 900 )) $(( 7 * 3600 + 40 * 60 )) ''
given_sample_service frontend c9d0e1f2a3b4c5d6 $(( 12 * 86400 + 5 * 3600 )) 0 '' \
  ActiveState=activating SubState=auto-restart

given_last_device 3f9c2a7b1e04 SBR -48 3 2.99
given_last_device 8d41e0c5a9b2 MT-V2 -63 21 3.02
given_last_device c7a05f3e9d18 SOP -71 95 3.58
given_last_device 51be7c2d04fa AST -89 260 3.60
given_last_device e2d9b4a17c60 SBR -66 1500 1.86
given_pending_task 8d41e0c5a9b2 upload
given_pending_task 51be7c2d04fa upload
given_pending_task 51be7c2d04fa download

given_gateway_health $(( 6 * 86400 + 4 * 3600 ))
print -r -- '0.62 0.55 0.48 1/298 41873' > "$GW_TEST_DIR/proc/loadavg"
print -r -- $'MemTotal:        4000000 kB\nMemFree:          300000 kB\nMemAvailable:     880000 kB' > "$GW_TEST_DIR/proc/meminfo"
export GW_TEST_CPUS=2
export GW_TEST_SD_TOTAL_KB=64000000 GW_TEST_SD_USED_KB=7680000
export GW_TEST_ROOT_TOTAL_KB=8000000 GW_TEST_ROOT_USED_KB=3280000

mkdir -p "$output_dir"
for command in status devices health; do
  terminal=$GW_TEST_DIR/$command.terminal
  {
    print -r -- $'\e[90m$\e[0m gw '"$command alpha"
    GW_COLOR=always "$GW_REPO/bin/gw" "$command" alpha 2>&1
  } > "$terminal"
  render_svg "$terminal" "$output_dir/$command.svg" "gw $command output"
  print -r -- "${output_dir#$root/}/$command.svg"
done
