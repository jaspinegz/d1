# vim: set ft=c:syntax=c
{
  pkgs,
}:

''
#include <err.h>
#include <fnmatch.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

int main(int argc, char *argv[]) {
  if (argc < 1) return 1;
  if (!fnmatch("README.[1-9]", argv[1], 0) ||
      !fnmatch("*README.[1-9]", argv[1], 0)) {
    execlp("${pkgs.mandoc}/bin/mandoc", "mandoc", "-T", "html", (char*)NULL);
    err(127, "mandoc");
  } else if (!fnmatch("README.md", argv[1], 0) || 
      !fnmatch("*README.md", argv[1], 0)) {
    execlp("${pkgs.md4c}/bin/md2html", "md2html", "--github", (char*)NULL);
    err(127, "md2html");
  } else {
    //TODO this is broken i guess
    int c;
    while((c = getchar()) != EOF) {
      putchar(c);
    }
    return 0;
  }
  return 1;
}
''
