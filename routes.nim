  get "/playground":
    resp genPlayground()

  post "/compile":
    if tryExec(db, sql"""insert into playground(
      title,email,code,comment,target,mode,gc,stylecheck,exceptions,os,cpu,ssl,
      threads,strip,python,flto,fastmath,hardened,fontsize,fontfamily,expiration,stdin
    ) values (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)""",
      @"title".normalize,
      @"code".strip,
      @"commentinput".strip,
      @"target".normalize,
      @"mode".normalize,
      @"gc".normalize,
      @"stylecheck".normalize,
      @"exceptions".normalize,
      @"os".normalize,
      @"cpu".normalize,
      if @"ssl" == "on": 1 else: 0,
      if @"threads" == "on": 1 else: 0,
      if @"threads" == "on": 1 else: 0,
      if @"strip" == "on": 1 else: 0,
      if @"python" == "on": 1 else: 0,
      if @"flto" == "on": 1 else: 0,
      if @"fastmath" == "on": 1 else: 0,
      if @"hardened" == "on": 1 else: 0,
      @"fontsize".parseInt.int8.Positive,
      @"fontfamily".strip,
      @"expiration".parseInt.int8.Positive,
      @"stdin".strip,
    ):
      echo ${
        "code": @"code",
        "stats": @"stats",
        "commentoutput": @"commentoutput",
        "commentinput": @"commentinput",
        "target": @"target",
        "mode": @"mode",
        "gc": @"gc",
        "stylecheck": @"stylecheck",
        "exceptions": @"exceptions",
        "os": @"os",
        "cpu": @"cpu",
        "ssl": @"ssl",
        "threads": @"threads",
        "strip": @"strip",
        "python": @"python",
        "flto": @"flto",
        "fastmath": @"fastmath",
        "hardened": @"hardened",
        "fontsize": @"fontsize",
        "fontfamily": @"fontfamily",
        "title": @"title",
        "expiration": @"expiration",
        "stdin": @"stdin"
      }
    else:
      resp "FAIL"
    when not defined(release):
      echo ${
        "code": @"code",
        "stats": @"stats",
        "commentoutput": @"commentoutput",
        "commentinput": @"commentinput",
        "target": @"target",
        "mode": @"mode",
        "gc": @"gc",
        "stylecheck": @"stylecheck",
        "exceptions": @"exceptions",
        "os": @"os",
        "cpu": @"cpu",
        "ssl": @"ssl",
        "threads": @"threads",
        "strip": @"strip",
        "python": @"python",
        "flto": @"flto",
        "fastmath": @"fastmath",
        "hardened": @"hardened",
        "fontsize": @"fontsize",
        "fontfamily": @"fontfamily",
        "title": @"title",
        "expiration": @"expiration",
        "stdin": @"stdin"
      }


# strip code
# autoformat code
# save code to file
# compile code via firejails
# redirect to the same page with code
