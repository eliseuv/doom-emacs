# Prints "category module [+flag...]" for each enabled module in a doom! block.
# Joins the block first, so "(module +flag ...)" entries split across lines
# parse as one entry; commented-out modules are dropped with the comments.
/\(doom! / { inblock = 1 }
inblock {
  line = $0; sub(/;.*/, "", line); text = text " " line
}
END {
  gsub(/\(/, " ( ", text); gsub(/\)/, " ) ", text)
  n = split(text, t, /[ \t\n]+/); depth = 0
  for (i = 1; i <= n; i++) {
    w = t[i]; if (w == "") continue
    if (w == "(") { depth++; if (depth == 2) cur = ""; continue }
    if (w == ")") { if (depth == 2 && cur != "") print cat, cur; depth--; continue }
    if (depth == 1 && w ~ /^:/) { cat = substr(w, 2); continue }
    if (depth == 1 && w != "doom!") { print cat, w; continue }
    if (depth == 2) cur = (cur == "" ? w : cur " " w)
  }
}
