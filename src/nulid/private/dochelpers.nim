import std/[
  strformat,
  macros
]

macro ct(s: static string) = newCommentStmtNode(s)

template fmtCmnt*(s: static string): untyped = ct(&s)