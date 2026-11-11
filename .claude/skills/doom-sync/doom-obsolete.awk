# Prints NAME<TAB>file:line<TAB>message for every symbol Doom marks obsolete,
# either inside its definition, (declare (obsolete ...)), or by a top-level
# make-obsolete / define-obsolete-* form.
/^\((defun|defmacro|defsubst|cl-defun|cl-defmacro|defvar|defcustom|defalias)[ ]/ {
  name = $2; gsub(/^'/, "", name); defline = FNR
}
/\(declare .*\(obsolete/ && name != "" {
  msg = $0; sub(/.*\(obsolete[ ]*/, "", msg); print name "\t" FILENAME ":" defline "\t" msg
}
/\((make-obsolete|make-obsolete-variable|define-obsolete-function-alias|define-obsolete-variable-alias)[ ]+'/ {
  n = $0
  sub(/.*\((make-obsolete|make-obsolete-variable|define-obsolete-function-alias|define-obsolete-variable-alias)[ ]+'/, "", n)
  sub(/[ )].*/, "", n)
  print n "\t" FILENAME ":" FNR "\t" $0
}
