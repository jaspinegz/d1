# vim: set ft=c:syntax=c
{
  pkgs,
}:

''
#include <err.h>
#include <stdio.h>
#include <stdlib.h> // system()
#include <string.h> // strncat()
#include <unistd.h> // access(), fork(), execl()
#include <libgen.h>
#include <sys/wait.h> // wait()

/*
 * usage: mirror <path/to/MIRRORFILE>
 */
int main(int argc, char *argv[]) {
    if (argc < 2) return 1;

    char *MIRRORFILE = argv[1];
    FILE *fp = fopen(MIRRORFILE, "r");

    if (fp == NULL) {
        fprintf(stderr, "cannot open MIRRORFILE at '%s'\n", MIRRORFILE);
        exit(EXIT_FAILURE);
    }

    char   *parent = dirname(MIRRORFILE);
    char   *line = (char*)NULL;
    size_t  len = 0;
    ssize_t read;
    while ((read = getline(&line, &len, fp)) != -1) {
        const char *delim = " \t;";

        char mirrorpath[1024];
        mirrorpath[0] = '\0';
        const int n_mirrorpath = sizeof(mirrorpath);

        int retcode = -1;

        //MIRRORFILE format:
        //https://www.example.com/path/to/repository.git ; repository.git ; A written description of the repository.
        char *linedup, *str, *_saveptr;
        linedup = str = (char*)strdup(line);
        
        char *link = strtok_r(str, delim, &_saveptr);
        printf("link=%s\n", link);
        char *name = strtok_r(NULL, delim, &_saveptr);
        printf("name=%s\n", name);
        char *description = strtok_r(NULL, ";", &_saveptr);
        printf("desc=%s\n", description);
        while (description[0] == ";" || description[0] == " ")
          description++;

        strncat(mirrorpath, parent, n_mirrorpath - 1);
        strncat(mirrorpath, "/",    n_mirrorpath - 1);
        strncat(mirrorpath, name,   n_mirrorpath - 1);
        
        printf("mirrorpath=%s\n", mirrorpath);
        fflush(stdout);

        if (access(mirrorpath, F_OK) != 0) {
          fprintf(stdout, "%s doesn't exist, creating bare Git repository...\n", mirrorpath);

          chdir(parent);

          pid_t p;
          if ((p = fork()) < 0) {
            exit(EXIT_FAILURE);
          } else if (p == 0) {
            execl("${pkgs.git}/bin/git", "git", "clone", "--bare", "--mirror", link, name, (char*)NULL);
          } else {
            int wstatus;
            waitpid(p, &wstatus, 0);
            retcode = WEXITSTATUS(wstatus);
            if (retcode != 0) {
              fprintf(stderr, "error value (%d) when trying to initialize git repository\n", retcode);
              exit(EXIT_FAILURE);
            }
          }
        }

        chdir(mirrorpath);

        pid_t p;
        if ((p = fork()) < 0) {
          exit(EXIT_FAILURE);
        } else if (p == 0) {
          execl("${pkgs.git}/bin/git", "git", "fetch", "-vvv", (char*)NULL);
        } else {
          int wstatus;
          waitpid(p, &wstatus, 0);
          retcode = WEXITSTATUS(wstatus);
          if (retcode != 0) {
            fprintf(stderr, "error value (%d) when trying to fetch git repository\n", retcode);
            exit(EXIT_FAILURE);
          }
        }

        char description_path[1024];
        int  n_description_path = sizeof(description_path);
        description_path[0] = '\0';
        strncat(description_path, mirrorpath,     n_description_path);
        strncat(description_path, "/",            n_description_path);
        strncat(description_path, "description",  n_description_path);

        FILE *description_fp = fopen(description_path, "w");
        if (description_fp != NULL) {
          fprintf(description_fp, "%s\n", description);
          fflush(description_fp);
          fclose(description_fp);
        }

        free(linedup);
    }

    fclose(fp);

    return 1;
}
''
