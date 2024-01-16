#!/bin/bash

# Run thin server using a rackup file
#       Ruby with a 'run rack_app' (rack_app is a class responding to a 'def call(env)' method )
#       rather than 'Rack::Handler::Thin.run rack_app, Host: '127.0.0.1', Port: PORT'
# thin.yml specifies port
#    The profile can set a uid/gid that the thin server process runs as
# The Apparmor profile will be for the thin server, not the ruby script

# I'm not sure why, but if thin isn't run from the root dir, some, not all, of my file accesses
# fail. I have checked, and they are using absolute paths? Error in thin.log:
#    line 0: Cannot load input from '/wikk/var/tmp/netstat/dist_t1680394037384956.plot'
# Yet running thin from / works fine.

# I have set chdir '/' in the yml file too. Not sure which fixed the issue.

BASEDIR="/wikk/www/rpc"
(cd /; ${BASEDIR}/wikk_thin -R ${BASEDIR}/rpc.ru start -C ${BASEDIR}/thin.yml)
