#!/bin/bash

# Run thin server using a rackup file
#       Ruby with a 'run rack_app' (rack_app is a class responding to a 'def call(env)' method )
#       rather than 'Rack::Handler::Thin.run rack_app, Host: '127.0.0.1', Port: PORT'
# thin.yml specifies port
#    The profile can set a uid/gid that the thin server process runs as
# The Apparmor profile will be for the thin server, not the ruby script
(cd /wikk/www/rpc; ./wikk_thin -R rpc.ru start -C thin.yml)
