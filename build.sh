cp -v database.db database.`date +%d%b%Y`.db
rm -v README.md
rm -v LICENSE
chmod ugo-w examples.html
chmod ugo-w index.nimf
chmod ugo-w main.nim
nim c -d:release -d:danger --gc:arc -d:ssl main.nim
chmod ugo-w main
