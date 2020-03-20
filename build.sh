cp -v database.db database.`date +%d%b%Y`.db
rm -v README.md
rm -v LICENSE
rm -v code.deps
chmod ugo-w examples.html
chmod ugo-w index.nimf
chmod ugo-w main.nim
nim c -f -d:release -d:danger --gc:markAndSweep -d:ssl -d:noSignalHandler --passL:-s --listFullPaths:off --excessiveStackTrace:off --tlsEmulation:off --exceptions:goto --passC:"-flto -ffast-math -march=native -mtune=native -fsingle-precision-constant" main.nim
chmod ugo-w main
