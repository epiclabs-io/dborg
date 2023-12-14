# dBorg - borg over OpenVPN

This toolkit is a simple backup solution that can run on any machine with Docker.

Configure by editing the files in `config/`:

- `backup.conf` main settings
- `borg_repokey` borg repo passphrase
- `patterns.txt` exclude / include lists

```
dBorg -- Borg over OpenVPN tool. (c) Epic Labs 2023

 usage:

dborg.sh <command> parameters ...

commands:
create <prefix> <local path> : Creates a backup archive of the given local path with a prefix
shell [local_path] : opens a shell to run borg commands. If a local_path is given, it will be mapped from the host
mount [mount point path] : mounts the backup repository in the given local path. If ommited, it will mount in /media/backup
build : rebuilds the synobackup docker image
any other command is passed to borg in the container.
```
