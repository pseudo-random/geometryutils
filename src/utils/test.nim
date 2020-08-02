# MIT License
# 
# Copyright (c) 2020 pseudo-random <josh.leh.2018@gmail.com>
# 
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

import macros, terminal, strutils, sequtils, sugar

proc echo_test(name: string, failed_tests: seq[string]) =
  var text = ""
  if failed_tests.len == 0:
    set_foreground_color(fgGreen)
    stdout.write("[✓]")
  else:
    set_foreground_color(fgRed)
    stdout.write("[x]")
  reset_attributes()
  echo " ", name
  for info in failed_tests:
    echo info.split("\n").map(line => "\t" & line).join("\n")

proc run_test(test: bool, name: string, failed_tests: var seq[string]) =
  if not test:
    failed_tests.add(name)

macro test*(name: static[string], body: untyped) =
  var stmt_list = new_nim_node(nnkStmtList)
  let failed_tests_sym = gen_sym(nskVar, "failed_tests")

  stmt_list.add(new_nim_node(nnkVarSection)
    .add(new_nim_node(nnkIdentDefs)
      .add(failed_tests_sym)
      .add(new_nim_node(nnkBracketExpr)
        .add(bind_sym "seq")
        .add(bind_sym "string"))
      .add(new_nim_node(nnkEmpty))))

  for test in body:
    let test_name = test.line_info
    stmt_list.add(new_call(bind_sym("run_test"),
      test, new_lit(test_name), failed_tests_sym
    ))

  stmt_list.add(new_call(bind_sym("echo_test"),
    new_lit(name), failed_tests_sym
  ))

  return stmt_list

proc between*[T](x: T, lower, upper: T): bool =
  lower < x and x < upper
