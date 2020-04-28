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
