
import strutils, db_sqlite, json, strtabs, os, osproc, random, jester, net, packages/docutils/rstgen
include "index.nimf"       # Include the NimF template.

let db = db_sqlite.open("database.db", "", "", "")
exec(db, sql"""
  create table if not exists playground(
    id             integer         primary key,
    creation       timestamp       not null    default (strftime('%s', 'now')),
    url            varchar(9)      not null    unique,
    filejson       varchar(999)    not null,
    code           varchar(999)    not null,
    comment        varchar(99)     not null,
    target         varchar(9)      not null,
    mode           varchar(9)      not null,
    gc             varchar(9)      not null,
    stylecheck     varchar(9)      not null,
    exceptions     varchar(9)      not null,
    cpu            varchar(9)      not null,
    ssl            integer         not null    default 0,
    threads        integer         not null    default 0,
    strip          integer         not null    default 1,
    python         integer         not null    default 0,
    flto           integer         not null    default 0,
    fastmath       integer         not null    default 0,
    marchnative    integer         not null    default 0,
    fontsize       integer         not null    default 15,
    fontfamily     varchar(9)      not null,
    expiration     integer         not null    default 7
  );
""")                 # Create Playground DB Table.

routes:
  get "/":
    resp genPlayground(recents = getAllRows(db, sql"select url from playground order by creation limit 20"))

  get "/@urls":
    doAssert @"urls".len > 3 and @"urls".len < 10, "Wrong Invalid URL for a Playground"
    let row = getRow(db, sql"""
        select creation, code, filejson, comment, target, mode, gc, stylecheck, exceptions, cpu, ssl, threads, strip, python, flto, fastmath, marchnative, fontsize, fontfamily, expiration
        from playground
        where url = ?
      """, @"urls")
    resp genPlayground(
      urls = @"urls", filejson = row[2], code = row[1], htmlcomment = row[3], target = row[4],
      mode = row[5], gc = row[6], stylecheck = row[7], exceptions = row[8], cpu = row[9], hosting = $request.host,
      ssls = row[10], threads = row[11], strips = row[12], python = row[13], flto = row[14], fastmath = row[15], marchnative = row[16],
      fontsize = parseInt(row[17]), fontfamily = row[18], expiration = parseInt(row[19]), cancompile = false,
      recents = getAllRows(db, sql"select url from playground order by creation limit 20")
    )

  post "/compile":
    const x = [
      "firejail --noprofile --timeout='00:05:00'",
      "--overlay-tmpfs",
      "--rlimit-sigpending=1 --rlimit-nofile=99 --rlimit-fsize=9216000000 --rlimit-as=128000000",
      "--shell=none --x11=none",
      "--disable-mnt --apparmor --ipc-namespace",
      "--name=nim --hostname=nim",
      "--no3d --nodvd --nogroups --nonewprivs",
      "--nosound --novideo --notv",
      "--seccomp --net=none",
      "--memory-deny-write-execute",
      "--noexec='"
    ].join" "
    let
      fontsizes: range[10..50] = @"fontsize".parseInt
      expirations: range[1..99] = @"expiration".parseInt
      targets = @"target".normalize
      modes = @"mode".normalize
      gcs = @"gc".strip
      stylechecks = @"stylecheck".strip
      exceptions = @"exceptions".normalize
      cpus = @"cpu".strip
      fontfamilys = @"fontfamily".strip
      urls = @"url".strip.normalize.multiReplace(@[(" ", "_"), ("\t", "_"), ("\n", "_"), ("\v", "_"), ("\c", "_"), ("\f", "_"), ("-", "_")])
      jsons = parseJson(@"filejson").pretty.strip
      comnt = @"comment".strip
      folder = "/tmp" / urls
    # Validation
    doAssert targets in ["c", "cpp", "objc", "js -d:nodejs", "js", "check"]
    doAssert modes in ["", "-d:release", "-d:release -d:danger"]
    doAssert gcs in ["", "--gc:refc", "--gc:boehm", "--gc:markAndSweep", "--gc:go", "--gc:none", "--gc:regions", "--gc:arc", "--gc:orc"]
    doAssert stylechecks in ["", "--styleCheck:off", "--styleCheck:hint", "--styleCheck:error"]
    doAssert exceptions in ["", "--exceptions:setjmp", "--exceptions:goto", "--exceptions:cpp", "--exceptions:quirky"]
    doAssert cpus in ["", "--cpu:i386 --passC:-m32 --passL:-m32"]
    doAssert fontfamilys in ["Fira Code", "Oxygen Mono", "Roboto Mono", "Ubuntu Mono", "Inconsolata", "Monospace"]
    doAssert urls.len > 3 and urls.len < 10, "Wrong Invalid URL for a Playground"
    doAssert comnt.len < 1000
    doAssert jsons.len < 1000
    let comments = if comnt.len > 1:
      try: rstToHtml(comnt, {}, newStringTable(modeStyleInsensitive)) except: comnt
      else: ""
    # Process
    discard existsOrCreateDir folder
    defer: removeDir folder
    if likely(targets notin ["js -d:nodejs", "js", "check"]): writeFile(folder / "file.json", jsons)
    writeFile(folder / "code.nim", (if @"python" == "on": "import nimpy, pylib\n" else: "") &  @"code".strip)
    var (output, exitCode) = execCmdEx("nimpretty --indent:2 --maxLineLen:999 " & folder / "code.nim")
    when not defined(release): echo exitCode, "\tnimpretty"
    if exitCode == 0:
      let codez = readFile(folder / "code.nim").strip
      doAssert codez.len > 4 and codez.len < 1000
      writeFile(folder / "dumper.nim", "import macros;dumpAstGen:\n" & codez.indent(2))
      (output, exitCode) = execCmdEx("nim c --verbosity:0 --hints:off " & folder / "dumper.nim")
      when not defined(release): echo exitCode, "\tdumper"
      if exitCode == 0:
        let astz = output.strip
        (output, exitCode) = execCmdEx("nim genDepend --verbosity:0 --hints:off " & folder / "code.nim")
        when not defined(release): echo exitCode, "\tgendepend"
        if exitCode == 0:
          (output, exitCode) = execCmdEx("dot -Tsvg " & folder / "code.dot -o " & folder / "code.svg")
          when not defined(release): echo exitCode, "\tdot"
          if exitCode == 0:
            let dot = readFile(folder / "code.svg").strip.multiReplace(@[
              ("fill=\"white\"", "fill=\"#ccc\""),                     # 200 IQ Graphic Design
              ("<ellipse fill=\"none\"", "<ellipse fill=\"#ffe953\""), # Nothing from Stackoverflow worked
              ("font-family=\"Times,serif\"", "font-family=\"Fira Code\""),
              ("transform=\"scale(1 1) rotate(0) ", "transform=\"scale(0.5 0.5) rotate(0) "),
              ("<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"no\"?>", "")]
            )
            let cmd = [
              x & folder & "/' ",
              "nim --embedsrc:on --excessiveStackTrace:off --asm --nimcache:" & folder & "/ --outdir:" & folder & "/",
              targets, modes, gcs, stylechecks, exceptions, cpus,
              if @"ssl" == "on": "-d:ssl" else: "",
              if @"threads" == "on": "--threads:on" else: "",
              if @"strip" == "on": "--passL:-s" else: "",
              if @"flto" == "on": "--passC:-flto" else: "",
              if @"fastmath" == "on": "--passC:-ffast-math --passC:-fsingle-precision-constant" else: "",
              if @"marchnative" == "on": "--passC:-march=native --passC:-mtune=native" else: "",
              folder / "code.nim"].join" "
            (output, exitCode) = execCmdEx(cmd)
            when not defined(release): echo exitCode, "\t", cmd
            if exitCode == 0:
              when not defined(release): echo existsFile(folder / "code"), " Binary Exists"
              let sourcec = case targets
                of "c":    "@mcode.nim.c"
                of "cpp":  "@mcode.nim.cpp"
                of "objc": "@mcode.nim.m"
                of "js -d:nodejs", "js": "code.js"
                else: ""
              let ccode = if likely(sourcec.len > 0): readFile(folder / sourcec).strip.replace("\t", "  ") else: ""
              let sourceasm = case targets
                of "c":   "@mcode.nim.c.asm"
                of "cpp": "@mcode.nim.cpp.asm"
                else: ""
              let asmcode = if likely(sourceasm.len > 0): readFile(folder / sourceasm).strip.replace("\t", " ") else: ""
              let outputs = output.strip
              (output, exitCode) = execCmdEx("strip --strip-all --remove-section=.comment --remove-section=.note.gnu.gold-version --remove-section=.note --remove-section=.note.gnu.build-id --remove-section=.note.ABI-tag " & folder / "code")
              when not defined(release): echo exitCode, "\tstrip"
              if exitCode == 0:
                let fsize = if likely(targets in ["c", "cpp", "objc"]):
                  try: getFileSize(folder / "code").int div 1024 except: 0
                  else: 0
                let recents = getAllRows(db, sql"select url from playground order by creation limit 20")
                when not defined(release): echo "OK\t", recents
                if tryExec(db, sql"delete from playground where creation > DATETIME('now', '-' || expiration || ' day')"): # https://stackoverflow.com/a/45202107
                  when not defined(release): echo "OK\tDelete expired playgrounds"
                  if tryExec(db, sql"""
                    insert into playground(
                      code, filejson, comment, target, mode, gc, stylecheck, exceptions, cpu, ssl, threads,
                      strip, python, flto, fastmath, marchnative, fontsize, fontfamily, url, expiration
                    ) values (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)""",
                      codez, jsons, comments, targets, modes, gcs, stylechecks, exceptions, cpus,
                      if @"ssl" == "on": 1 else: 0, if @"threads" == "on": 1 else: 0, if @"strip" == "on": 1 else: 0, if @"python" == "on": 1 else: 0,
                      if @"flto" == "on": 1 else: 0, if @"fastmath" == "on": 1 else: 0,  if @"marchnative" == "on": 1 else: 0,
                      fontsizes, fontfamilys, urls, expirations
                    ):
                    when not defined(release): echo "OK\tSave new playground ", urls
                    resp genPlayground(
                      urls = urls, filejson = jsons, code = codez, htmlcomment = comments, target = targets,
                      mode = modes, gc = gcs, stylecheck = stylechecks, exceptions = exceptions, cpu = cpus,
                      ssls = @"ssl", threads = @"threads", strips = @"strip", python = @"python", flto = @"flto", fastmath = @"fastmath", marchnative = @"marchnative",
                      fontfamily = fontfamilys, fontsize = fontsizes, expiration = expirations, fsize = fsize, cancompile = false,
                      astz = astz, dot = dot, ccode = ccode, asmcode = asmcode, outputs = outputs, recents = recents, hosting = $request.host,
                    )
                  else: resp output.strip
              else: resp output.strip
            else: resp output.strip
          else: resp output.strip
        else: resp output.strip
      else: resp output.strip
    else: resp output.strip
