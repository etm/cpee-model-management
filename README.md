# CPEE Model Manager

To install the model manager go to the commandline

```bash
 gem install cpee-model-manager
 cpee-moma new moma
 cd moma
 ./moma start
```
The service is running under port 9316. If this port has to be changed (or the
host, or local-only access, ...), modify the file moma.conf and change:

```yaml
 :port: 9250
```

You may also change the directory where the models are saved:

```yaml
 :models: /var/models
```

If the models directory is a git, each model change is automatically commited and
pushed IF push works without passwort. So take care to either use a password-less key or
in case of http basic auth, add user and password to the url.
