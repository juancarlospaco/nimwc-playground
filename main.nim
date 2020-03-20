import strutils, db_sqlite, json, strtabs, os, osproc, random, net, times, packages/docutils/rstgen, jester, qr
randomize()
include "index.nimf", "error.nimf"

let db = db_sqlite.open("database.db", "", "", "")
exec(db, sql"""
  create table if not exists playground(
    id             integer         primary key,
    creation       timestamp       not null    default (strftime('%s', 'now')),
    url            varchar(9)      not null    unique,
    filejson       varchar(999)    not null,
    code           varchar(999)    not null,
    comment        varchar(99)     not null,
    stdouts        varchar(9999)   not null,
    ccode          varchar(9999)   not null,
    asmcode        varchar(9999)   not null,
    astcode        varchar(9999)   not null,
    dot            varchar(9999)   not null,
    fsize          integer         not null    default 0,
    target         varchar(9)      not null,
    mode           varchar(9)      not null,
    gc             varchar(9)      not null,
    exceptions     varchar(9)      not null,
    cpu            varchar(9)      not null,
    ssl            integer         not null    default 0,
    threads        integer         not null    default 0,
    python         integer         not null    default 0,
    flto           integer         not null    default 0,
    fastmath       integer         not null    default 0,
    marchnative    integer         not null    default 0,
    hardened       integer         not null    default 0,
    pastebin       integer         not null    default 0,
    fontsize       integer         not null    default 15,
    fontfamily     varchar(9)      not null,
    expiration     integer         not null    default 9,
    oss            varchar(999)    not null
  ); """)                 # Create Playground DB Table.


routes:
  get "/":
    resp genPlayground(recents = getAllRows(db, sql"select url from playground order by creation limit 25"), simple = request.params.hasKey"simple")

  get "/@urls":
    if likely(@"urls".len > 3 and @"urls".len < 10):
      when not defined(release): echo "URLS\t", @"urls"
      let row = getRow(db, sql"""
          select creation, code, filejson, comment, stdouts, ccode, asmcode, astcode, dot, fsize, target, mode, gc, exceptions, cpu, ssl, threads, python, flto, fastmath, marchnative, hardened, pastebin, fontsize, fontfamily, expiration, oss
          from playground where url = ? """, @"urls")
      resp genPlayground(
        urls = @"urls", code = row[1], filejson = row[2], htmlcomment = row[3], stdouts = row[4], ccode = row[5], asmcode = row[6], astcode = row[7], dot = row[8], fsize = parseInt(row[9].strip.normalize),
        target = row[10], mode = row[11], gc = row[12], exceptions = row[13], cpu = row[14], ssls = row[15] == "1", threads = row[16] == "1", creation = parseInt(row[0]).int64.fromUnix.local,
        python = row[17] == "1", flto = row[18] == "1", fastmath = row[19] == "1", marchnative = row[20] == "1", hardened = row[21] == "1", pastebin = row[22] == "1",
        fontsize = parseInt(row[23].strip.normalize), fontfamily = row[24], expiration = parseInt(row[25].strip.normalize), oss = row[25], cancompile = false, hosting = $request.host,
        recents = getAllRows(db, sql"select url from playground order by creation limit 25"), simple = request.params.hasKey"simple"
      )
    else: resp genPlayground(recents = @[@[""]], simple = request.params.hasKey"simple")

  post "/compile":
    const
      x = "firejail --quiet --noprofile --timeout='00:05:00' --nice=20 --noroot --read-only='/home/' --seccomp --disable-mnt --rlimit-sigpending=9 --rlimit-nofile=99 --rlimit-fsize=9216000000 --shell=none --x11=none --ipc-namespace --name=nim --hostname=nim --no3d --nodvd --nogroups --nonewprivs --nosound --novideo --notv --net=none --memory-deny-write-execute"
      hf = "-fstack-protector-all -Wstack-protector --param ssp-buffer-size=4 -pie -fPIE -Wformat -Wformat-security -D_FORTIFY_SOURCE=2 -Wall -Wextra -Wconversion -Wsign-conversion -mindirect-branch=thunk -mfunction-return=thunk -Wl,-z,relro,-z,now -Wl,-z,noexecstack -fsanitize=signed-integer-overflow -fsanitize-undefined-trap-on-error -fno-common"
      n = "nim --colors:off --parallelBuild:1 --listCmd --hint[Conf]:off --hint[Processing]:off --styleCheck:hint --lineTrace:off --embedsrc:on --excessiveStackTrace:off --passL:-s "
      s = "strip --strip-all --remove-section=.comment --remove-section=.note.gnu.gold-version --remove-section=.note --remove-section=.note.gnu.build-id --remove-section=.note.ABI-tag "
      #css = "<style>" & staticRead"nimdoc.out.css".strip.unindent(99) & "</style>"
    let
      isPastebin = @"pastebin" == "on"
      fontfamilys = @"fontfamily".strip
      f = try: parseInt(@"fontsize") except: 15
      fontsizes = if f in 10..50: f else: 15
      e = try: parseInt(@"expiration") except: 9
      expirations = if e in 9..99: e else: 9
      urls = @"url".strip.normalize.multiReplace(@[(" ", "_"), ("\t", "_"), ("\n", "_"), ("\v", "_"), ("\c", "_"), ("\f", "_"), ("-", "_")])
    when not defined(release): echo "OK\tis Pastebin ", isPastebin
    if isPastebin:
      if tryExec(db, sql"""
        insert into playground(
          code, filejson, comment, stdouts, ccode, asmcode, astcode, dot, fsize, target, mode, gc, exceptions, cpu, ssl, threads,
          python, flto, fastmath, marchnative, hardened, pastebin, fontsize, fontfamily, url, expiration, oss
        ) values (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)""",
          @"code".strip, "{}", "", "", "", "", "", "", 0, "c", "", "", "", "", 0, 0, 0, 0, 0, 0, 0, 1, fontsizes, "Fira Code", urls, expirations, ""
        ):
        when not defined(release): echo "OK\tSave new Pastebin ", urls
        resp genPlayground(
          urls = urls, code = @"code".strip, pastebin = true, fontfamily = fontfamilys, fontsize = fontsizes,
          expiration = expirations, cancompile = false, recents = @[@[""]], hosting = $request.host, simple = request.params.hasKey"simple"
        )
    else:
      let
        gcs = @"gc".strip
        oss = @"oss".strip
        cpus = @"cpu".strip
        folder = "/tmp" / urls
        comnt = @"comment".strip
        modes = @"mode".normalize
        targets = @"target".normalize
        exceptions = @"exceptions".normalize
        jsons = parseJson(@"filejson").pretty.strip
      try: # Validation
        doAssert comnt.len < 1000, "Comment is too long, 1000 chars max limit"
        doAssert jsons.len < 1000, "JSON is too long, 1000 chars max limit"
        doAssert @"code".len < 1000, "Code is too long, 1000 chars max limit"
        doAssert urls.len > 3 and urls.len < 10, "Wrong Invalid URL for a Playground, must be 9 ASCII chars"
        doAssert modes in ["", "-d:release", "-d:release -d:danger"], "Wrong invalid Mode"
        doAssert cpus in ["", "--cpu:i386 --passC:-m32 --passL:-m32"], "Wrong invalid CPU"
        doAssert targets in ["c", "cpp", "objc", "js -d:nodejs", "js", "check", "e"], "Wrong invalid Target"
        doAssert fontfamilys in ["Fira Code", "Oxygen Mono", "Roboto Mono", "Ubuntu Mono", "Inconsolata", "Monospace"], "Wrong invalid Font Family Name"
        doAssert exceptions in ["", "--exceptions:setjmp", "--exceptions:goto", "--exceptions:cpp", "--exceptions:quirky"], "Wrong invalid Exceptions"
        doAssert gcs in ["", "--gc:refc", "--gc:boehm", "--gc:markAndSweep", "--gc:go", "--gc:none", "--gc:regions", "--gc:arc", "--gc:orc"], "Wrong invalid Memory Management Strategy"
        doAssert oss in ["", "--os:linux", "--os:standalone", "--os:windows --gcc.exe:x86_64-w64-mingw32-gcc --gcc.linkerexe:x86_64-w64-mingw32-gcc", "--os:android --gcc.exe:arm-linux-gnueabi-gcc --gcc.linkerexe:arm-linux-gnueabi-gcc"], "Wrong invalid OS"
      except:
        resp genError(error = getCurrentExceptionMsg())
      let isWin = oss == "--os:windows --gcc.exe:x86_64-w64-mingw32-gcc --gcc.linkerexe:x86_64-w64-mingw32-gcc"
      let isAndroid = oss == "--os:android --gcc.exe:arm-linux-gnueabi-gcc --gcc.linkerexe:arm-linux-gnueabi-gcc"
      let comments = if unlikely(comnt.len > 2):
        try: rstToHtml(comnt, {}, newStringTable(modeStyleInsensitive)) except: comnt & "\n\n Error parsing as RST/MD, fallback to plain text."
        else: ""
      discard existsOrCreateDir folder
      defer: removeDir folder
      if likely(targets notin ["js -d:nodejs", "js", "check"]): writeFile(folder / "file.json", jsons)
      let file = if targets == "e": "code.nims" else: "code.nim"
      let filepath = folder / file
      writeFile(filepath, (if @"python" == "on": "import nimpy, pylib\n" else: "") &  @"code".strip)
      var (output, exitCode) = execCmdEx("nimpretty --indent:2 --maxLineLen:999 " & filepath)
      when not defined(release): echo exitCode, "\tnimpretty"
      if exitCode == 0:
        let nimcode = readFile(filepath).strip
        writeFile(folder / "dumper.nim", "import macros;dumpAstGen:\n" & nimcode.indent(2))
        (output, exitCode) = execCmdEx(n & "check --hint[SuccessX]:off " & folder / "dumper.nim")
        when not defined(release): echo exitCode, "\tdumper"
        if exitCode == 0:
          let astcode = output.strip
          (output, exitCode) = execCmdEx(n & "genDepend " & filepath)
          when not defined(release): echo exitCode, "\tgenDepend"
          if exitCode == 0:
            (output, exitCode) = execCmdEx("dot -Tsvg " & folder / "code.dot -o " & folder / "code.svg")
            when not defined(release): echo exitCode, "\tdot"
            if exitCode == 0:
              let dot = readFile(folder / "code.svg").strip.multiReplace(@[
                ("fill=\"white\"", "fill=\"#ccc\""), 
                ("<ellipse fill=\"none\"", "<ellipse fill=\"#ffe953\""), 
                ("font-family=\"Times,serif\"", "font-family=\"Ubuntu Mono\""),
                ("<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"no\"?>", ""), 
                ("transform=\"scale(1 1) rotate(0) ", "transform=\"scale(0.75 0.75) rotate(0) "),
                ("\n<!-- Generated by graphviz version 2.42.3 (0)\n -->\n<!-- Title: code Pages: 1 -->\n", "")
              ])
              let cmd = [
                x, if @"run" == "on": "" else: "--noexec='" & folder & "/' " ,
                n & "--nimcache:" & folder & "/ --outdir:" & folder & "/",
                targets, modes, gcs, exceptions, cpus, oss,
                if not isAndroid: "--asm" else: "",
                if @"ssl" == "on": "-d:ssl" else: "",
                if @"threads" == "on": "--threads:on --experimental:parallel" else: "",
                if @"run" == "on" and not isWin: "--run" else: "",
                if @"flto" == "on": "--passC:-flto" else: "",
                if @"fastmath" == "on": "--passC:'-ffast-math -fsingle-precision-constant'" else: "",
                if @"marchnative" == "on": "--passC:'-march=native -mtune=native'" else: "",
                if @"hardened" == "on": "--assertions:on --checks:on --passC:'" & hf & "' --passL:'" & hf & "'" else: "",
                filepath].join" "
              (output, exitCode) = execCmdEx(cmd)
              when not defined(release): echo exitCode, "\t", cmd
              if exitCode == 0:
                when not defined(release): echo existsFile(folder / "code"), "\tBinary Exists"
                let sourcec = case targets
                  of "c":    "@mcode.nim.c"
                  of "cpp":  "@mcode.nim.cpp"
                  of "objc": "@mcode.nim.m"
                  of "js -d:nodejs", "js": "code.js"
                  else: ""
                let ccode = if likely(sourcec.len > 0 and not isAndroid): readFile(folder / sourcec).strip.replace("\t", "  ") else: ""
                let sourceasm = case targets
                  of "c":   "@mcode.nim.c.asm"
                  of "cpp": "@mcode.nim.cpp.asm"
                  else: ""
                let asmcode = if likely(sourceasm.len > 0 and not isAndroid): readFile(folder / sourceasm).strip.replace("\t", " ") else: ""
                let stdouts = output.strip
                if likely(targets in ["c", "cpp", "objc"]): (output, exitCode) = execCmdEx(s & folder / "code" & (if isWin: ".exe" else: ""))
                when not defined(release): echo exitCode, "\tstrip"
                if exitCode == 0:
                  if likely(targets in ["c", "cpp", "objc"]): (output, exitCode) = execCmdEx("upx -q -f --brute " & folder / "code" & (if isWin: ".exe" else: ""))
                  when not defined(release): echo exitCode, "\tupx"
                  if exitCode == 0:
                    let fsize = if likely(targets in ["c", "cpp", "objc", "js", "js -d:nodejs"]): getFileSize(folder / "code" & (if isWin: ".exe" elif targets in ["js", "js -d:nodejs"]: ".js" else: "")).int div 1024 else: 0
                    let recents = getAllRows(db, sql"select url from playground order by creation limit 25")
                    when not defined(release): echo "OK\t", recents
                    if sample([true, false]):  # 50/50 chance to delete expired playgrounds on each post.
                      discard tryExec(db, sql"delete from playground where creation > DATETIME('now', '-' || expiration || ' day')") # https://stackoverflow.com/a/45202107
                      when not defined(release): echo "OK\tDelete expired playgrounds"
                    if tryExec(db, sql"""
                      insert into playground(
                        code, filejson, comment, stdouts, ccode, asmcode, astcode, dot, fsize, target, mode, gc, exceptions, cpu, ssl, threads,
                        python, flto, fastmath, marchnative, hardened, fontsize, fontfamily, url, expiration, oss
                      ) values (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)""",
                        nimcode, jsons, comments, stdouts, ccode, asmcode, astcode, dot, fsize, targets, modes, gcs, exceptions, cpus,
                        if @"ssl" == "on": 1 else: 0, if @"threads" == "on": 1 else: 0, if @"python" == "on": 1 else: 0,
                        if @"flto" == "on": 1 else: 0, if @"fastmath" == "on": 1 else: 0, if @"marchnative" == "on": 1 else: 0, if @"hardened" == "on": 1 else: 0,
                        fontsizes, fontfamilys, urls, expirations, oss
                      ):
                      when not defined(release): echo "OK\tSave new Playground ", urls
                      resp genPlayground(
                        urls = urls, filejson = jsons, code = nimcode, htmlcomment = comments, oss = oss,
                        target = targets, mode = modes, gc = gcs, exceptions = exceptions, cpu = cpus, simple = request.params.hasKey"simple",
                        ssls = @"ssl" == "on", threads = @"threads" == "on", python = @"python" == "on", flto = @"flto" == "on", fastmath = @"fastmath" == "on", marchnative = @"marchnative" == "on", hardened = @"hardened" == "on",
                        fontfamily = fontfamilys, fontsize = fontsizes, expiration = expirations, fsize = fsize, cancompile = false,
                        astcode = astcode, dot = dot, ccode = ccode, asmcode = asmcode, stdouts = stdouts, recents = recents, hosting = $request.host,
                      )
      if exitCode != 0: resp genError(error = output.strip)
