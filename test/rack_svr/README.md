# Rack with thin server Tests

## Under 'thin start'

The thin_run.sh launches thin, with the thin.yml config file and the rpc.ru rack up file. This is a nice clean way to suid/sguid and pass in thin configuration. Multiple applications all look to be running as thin, so there would be one Apparmor profile. Separate Apparmor profiles could be achieved through duplicating the thin app.

## Running thin from inside the ruby script

The thin_run.c launches rpc.rb, which is identical to the rpc.ru file, excepting it doesn't use the thin.yml config. Instead, the `run` call is passed parameters. This method has the advantage, that each instance of the thin server is running under the ruby application name, so can have a separate Apparmor profile.


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
