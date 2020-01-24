  get "/playground":
    resp genPlayground()

  post "/compile":
    resp $request
