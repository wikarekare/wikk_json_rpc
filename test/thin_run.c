#include <stdio.h>
#include <unistd.h>
#include <errno.h>

int main( int argc, char ** argv, char ** envp )
{
char *n_envp[] = { "SHELL=/bin/bash", "USER=www-data", "HOME=/www-data", "PATH=/bin:/usr/bin:/usr/local/bin", "PWD=/wikk/www/rpc", NULL };
char *n_argv[] = { "/wikk/www/rpc/rpc", NULL };

  chdir("/wikk/www/rpc");
  if( setuid(geteuid()) ) perror( "setuid" );
  execve( n_argv[0], n_argv, n_envp );
  return errno;
}
