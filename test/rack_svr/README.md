# Rack with thin server Tests

## Under 'thin start'

The thin_run.sh launches thin, with the thin.yml config file and the rpc.ru rack up file. This is a nice clean way to suid/sguid and pass in thin configuration. Multiple applications will all run as thin, so there would be one Apparmor profile, unless you duplicate the bin/thin, then you can having one app per Apparmor profile.

Starting this way, thin is run as root, and needs write a thin.pid file. The pid directory must be owned by root or apparmor will DENY the file creation with capname="dac_override". It doesn't matter that root can write to the directory, even if it doesn't own it, nor that there is an apparmor rule that permits thin to write to the directory and the file. Thin then does a setuid/setgid to user specified in the yml file.

The apparmor profile also needed permission to change uid/gid, or it continued to run as root.
```
capability setgid,
capability setuid,
```

## Running thin from inside the ruby script, and launching with a suid binary

The thin_run.c launches rpc.rb, which is identical to the rpc.ru file, excepting it doesn't use the thin.yml config. Instead, the `run` call is passed parameters. This method has the advantage, that each instance of the thin server is running under the ruby application name, so can have a separate Apparmor profile (though that can be achieved with multiple bin/thin's too).


## Apache

I'm running tests behind apache, with the proxy modules included, and proxy anything going to /rpc with:
```
<Location "/rpc">
    ProxyPass "http://127.0.0.1:3223/"
    ProxyPassReverse "http://127.0.0.1:3223/"
</Location>
```

### Apparmor

Using proxying, the Apparmor profile is distinct from the apache2 profile, which allows a clean separation between what apache needs to be able to do, and what the ruby script needs to be able to do.
