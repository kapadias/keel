# shell-words.awk — a shell command as the shell will see it, for the branch guard.
#
#   awk -v out=A -f shell-words.awk   one simple command per line, each word kept whole (whitespace
#                                     inside a quoted word becomes \001), quotes and escapes removed
#   awk -v out=B -f shell-words.awk   quotes and escapes removed, whitespace kept, and every
#                                     ; & | ( ) ` a line break, quoted or not, so code inside a
#                                     quoted string (sh -c "…", "$(…)") is seen too
#
# The guard checks both: A keeps a quoted value in one piece (-c user.name="a b" is one word), B
# exposes whatever a quoted string holds. A match in either refuses.
#
# A commit message is masked as MSG, so its words are not read as flags or refs: a quoted argument
# of -m, --message, -F or --file (or -am, --message=…) in a command whose first word is git. Only in
# a plain command, with no $( ` <( >( ${ or << left, whose nested quoting this does not follow, and
# with quotes that balance; anything else stays exposed, which can only refuse more, never less.
# Claude Code's usual message, "$(cat <<'EOF' … EOF\n)", is literal (a quoted delimiter expands
# nothing) and counts as a quoted string. Comments are skipped as the shell skips them; $IFS is a
# space.
{ s = s (NR > 1 ? "\n" : "") $0 }

function endword() {
  if (w == "" && !q) return
  k++; tok[k] = w; tq[k] = q; tpre[k] = (q ? pre : w); tsep[k] = ""
  w = ""; q = 0; pre = ""
}
function sep(c) { k++; tok[k] = c; tsep[k] = c; tq[k] = 0 }

# "$(cat <<'DELIM'\n…\nDELIM\n)" -> "MSG": the body of a heredoc with a quoted delimiter is literal.
# Anything that does not fit that shape exactly is left alone.
function literal_heredocs(str,   out, p, tail, hdr, d, body, t, after) {
  out = ""
  while ((p = index(str, "\"$(cat <<")) > 0) {
    out = out substr(str, 1, p)
    tail = substr(str, p + 1)
    if (!match(tail, /^\$\(cat[ \t]*<<-?[ \t]*'[A-Za-z_][A-Za-z_0-9]*'[ \t]*\n/)) { str = tail; continue }
    hdr = substr(tail, 1, RLENGTH); body = substr(tail, RLENGTH + 1)
    d = hdr; sub(/^[^']*'/, "", d); sub(/'.*$/, "", d)
    t = index("\n" body, "\n" d "\n")
    if (t == 0) { str = tail; continue }
    after = substr(body, t + length(d) + 1)
    if (!match(after, /^[ \t\n]*\)"/)) { str = tail; continue }
    out = out "MSG\""
    str = substr(after, RLENGTH + 1)
  }
  return out str
}

END {
  gsub(/\$\{IFS\}|\$IFS/, " ", s)
  s = literal_heredocs(s)
  plain = (s !~ /\$\(|`|<\(|>\(|\$\{|<</)
  n = length(s); state = 0; w = ""; q = 0; pre = ""; k = 0
  for (i = 1; i <= n; i++) {
    c = substr(s, i, 1); nx = substr(s, i + 1, 1)
    if (state == 0) {
      if (c == "\\") { i++; if (nx != "\n") w = w nx }
      else if (c == "'") { if (!q) pre = w; q = 1; state = 1 }
      else if (c == "\"") { if (!q) pre = w; q = 1; state = 2 }
      else if (c == "$" && nx == "'") { if (!q) pre = w; q = 1; state = 3; i++ }
      else if (c == "$" && nx == "\"") { if (!q) pre = w; q = 1; state = 2; i++ }
      else if (c == "#" && w == "" && !q) { while (i < n && substr(s, i + 1, 1) != "\n") i++ }
      else if (c == " " || c == "\t") endword()
      else if (c ~ /[;&|()`<>\n]/) { endword(); sep(c) }
      else w = w c
    } else if (state == 1) {
      if (c == "'") state = 0; else w = w c
    } else if (state == 3) {
      if (c == "\\") { i++; w = w nx } else if (c == "'") state = 0; else w = w c
    } else {
      if (c == "\\" && (nx == "\"" || nx == "\\" || nx == "$" || nx == "`" || nx == "\n")) { i++; if (nx != "\n") w = w nx }
      else if (c == "\"") state = 0
      else w = w c
    }
  }
  if (state != 0) plain = 0 # quotes that do not balance: nothing is masked
  endword()

  if (plain) {
    start = 1; isgit = 0; pend = 0
    for (j = 1; j <= k; j++) {
      if (tsep[j] != "") {
        if (tsep[j] ~ /[;&|()`\n]/) { start = 1; isgit = 0 }
        pend = 0; continue
      }
      if (start) {
        if (!tq[j] && tok[j] ~ /^[A-Za-z_][A-Za-z0-9_]*\+?=/) continue # an assignment before the command
        isgit = (!tq[j] && tok[j] ~ /(^|\/)git$/); start = 0; pend = 0; continue
      }
      if (isgit && pend && tq[j]) { mask[j] = "MSG"; pend = 0; continue }
      pend = 0
      if (!isgit) continue
      if (!tq[j] && (tok[j] ~ /^-[A-Za-z]*m$/ || tok[j] == "--message" || tok[j] == "-F" || tok[j] == "--file")) pend = 1
      else if (tq[j] && tpre[j] ~ /^(-[A-Za-z]*m|--message=|-F|--file=)$/) mask[j] = tpre[j] "MSG"
    }
  }

  line = ""
  for (j = 1; j <= k; j++) {
    if (tsep[j] != "") {
      if (tsep[j] ~ /[<>]/) line = line " " tsep[j]
      else { print line; line = "" }
      continue
    }
    x = (j in mask) ? mask[j] : tok[j]
    if (out == "A") gsub(/[ \t\n]/, "\001", x)
    else gsub(/[;&|()`\n]/, "\n", x)
    line = (line == "" ? x : line " " x)
  }
  print line
}
