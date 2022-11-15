# Remote support


## Requirements
!!! note "If you wish to use the remote capabilities (Owncloud, Slack, SCP), you need [curl](https://curl.se/download.html), [scp, and ssh](https://www.openssh.com/) installed and configured"

## Slack

### Configuration
To use Slack support, you need a Slack Workspace where you have configured an endpoint.
Navigate to:
- Workspace settings
- Manage Apps
- Build
- Go through the configuration
  - Select a name and target workspace
  - Incoming Webhooks
    - Set to On
      - Add New Webhook
        - Select channel to use
        - Copy the hook and save it in a file

Endpoint.txt:
```bash
https://hooks.slack.com/services/xxxxx/yyyy
```
Test that it works
```bash
curl -X POST -H 'Content-type: application/json' --data '{"text":"Hello, World!"}' https://hooks.slack.com/services/xxx/yyyyyy
```
Where `x` and `y` are secret strings to be used to send messages, unique to your installation.
You can test if it works in DataCurator
```julia
using DataCurator
using SlurmMonitor
ep = "endpoint.txt"
e = SlurmMonitor.readendpoint(ep)
if !isnothing(e)
  SlurmMonitor.posttoslack("Test", e)
else
  @warn "Failed"
end
```
### Usage
Triggering sending of messages:

```toml
[global]
endpoint="endpoint.txt"
[any]
conditions=["is_csv_file"]
actions=["printtoslack", "Found missing csv file !!"]
```
You can also specify the endpoint on the command line
```
./datacurator.sif -r recipe.toml -e endpoint.txt
```

## Owncloud
In your [Owncloud account](https://owncloud.com/), go to your profile settings, security, and click on "Create new app passcode".
Next, create a json file with credentials, let's call it `owncloud.json`
```json
{"token":"yzzd","remote":"https://remote.sever.com/remote.php/webdav/my/directory/","user":"you"}
```
Where "yzzd" is the token you created.
DO NOT share this file.

### Usage
```toml
[global]
owncloud_configuration="owncloud.json"
[any]
conditions=["is_csv_file"]
actions=["upload_to_owncloud"]
```

## SCP
DataCurator can send data remotely using SCP.
For this to work, you need to have an SSH account with the remote server configured.
You can find tutorials on how to do this here:
- https://learn.microsoft.com/en-us/windows/terminal/tutorials/ssh
- https://linuxhandbook.com/ssh-basics/

Make sure you have configured key-based access, password based access will NOT work.

Next, you need to creat a `json` file, let's call it `ssh.json` for now, that looks like the below:
```json
{"port":"22","remote":"remote.server.name", "path":"/remote/directory","user":"you"}
```
In the global configuration section, then reference this file
```toml
[global]
scp_configuration = "ssh.json"
```
With this configured, DataCurator can now upload files that match your rules:
```toml
conditions=["is_csv_file"]
actions=["upload_to_scp"]
```

## Triggering remote scripts
You can request DataCurator to submit a script to a remote server.
This assumes you have SSH configured.
```toml
[global]

at_exit=["schedule_script", "runscript.sh"
```
where an example runscript is found [online](https://github.com/bencardoen/DataCurator.jl/blob/main/scripts/example_slurm.sh).
At the end of the curation, DataCurator will then execute:
```
scp runscript.sh you@remote.com:/your/dir/runscript.sh
ssh you@remote.com cd /your/dir/runscript.sh && sbatch runscript.sh
```
This first copies the script to the server, then calls the scheduler to schedule your script.
This assumes that:
- You configured SSH
- Your credentials are valid
- You have a SLURM account


## Remote execution of DataCurator
One way to remotely execute is to
- Transfer the Singularity image (or install remotely)
- Execute
For example:
```bash
scp datacurator.sif you@remote.com:/target/dir/datacurator.sif
ssh you@remote.com cd /target/dir && ./datacurator.sif -r recipe.toml -e endpoint.txt &
```
A more interactive way would be
```bash
scp datacurator.sif you@remote.com:/target/dir/datacurator.sif
ssh you@remote.com
you@remote.com>cd /target/dir
you@remote.com>tmux
you@remote.com>./datacurator.sif -r recipe.toml -e endpoint.txt &
you@remote.com>CTRL-B-D # logout but leave running
```

On SLURM based schedulers it would be recommended to do
```bash
scp datacurator.sif you@remote.com:/target/dir/datacurator.sif
ssh you@remote.com
you@remote.com>cd /target/dir
you@remote.com>tmux
you@remote.com>salloc --mem=64G .... ## Request resources from the cluster and execute in compute node
you@remote.com>./datacurator.sif -r recipe.toml -e endpoint.txt &
you@remote.com>CTRL-B-D # logout but leave running
```

## Notes
Please make sure the configurations of either service is ok before testing it in a recipe. Network based actions are brittle, and can hang. We try to use non-blocking actions where possible.
Note that for large transfers it can be easier to move all data to the remote server, and do the curation there. Naturally, network speed, disk speed and so forth determine when this is the case.
