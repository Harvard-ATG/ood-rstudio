# OOD RStudio App

This app contains a configuration for getting RStudio running in an [Apptainer](https://apptainer.org/) (formerly Singularity) container in HUIT Open OnDemand. It is based on the [RStudio app from the Ohio Supercomputing Center](https://github.com/OSC/bc_osc_rstudio_server), with modifications to run with Apptainer in our environment.

## Container

The base container used is defined in `/build/rstudio-base.def`. This is a direct translation of a Docker image from the [Rocker RStudio Docker repo](https://hub.docker.com/r/rocker/rstudio) ([Rocker homepage](https://rocker-project.org/)) into the Apptainer format. The definition file can be used to change the behavior to suit different use cases.

## Application

This application configuration is a bit more complex than our other setups. As such, there are more files that need to be in place in order for the app to work properly. In particular, there are more files in the `template` directory than is often the case. The files in `template` are propagated out to each session of the OOD app, so they are present in the session directory created when an interactive app runs. This OOD session folder is linked under a UUID from the OOD app session card in the OOD interface. The session directories are located at `/shared/home/<username>/ondemand/data/<sys|dev>/<app-name>/output/<session-uuid>`. The variables in that path are as follows:
- `username`: The NetID username of the user who ran the app
- `sys|dev`: For an app installed system-wide on the portal node at `/var/www/ood/apps/sys`, the session directory will appear under `sys`. For sandbox apps set up for an individual user, the directory will be under `dev`
- `app-name`: The name of the directory with the app configuration
- `session-uuid`: A randomly generated unique identifier for the session. This UUID is visible on the app session card in the OOD interface.

### Logging

Different phases of the app launch are logged in different locations. First, the `script.sh.erb` sets up the Apptainer spack environment and invokes `rstudio.script.sh`, both of which log to the `output.log` file in the OOD session folder. These scripts include a `set -x` directive to output the commands that run to stdout, which is directed to `output.log`. Anything printed to stdout, for example `echo` commands, in those scripts will appear in `output.log`

When the container and RStudio server are running, they should produce output in the `logs` directory of the session folder. This behavior is controlled by the `template/etc/rstudio/logging.conf.erb` file. This file is used by the RStudio server to configure logging because the Apptainer launch command links the `etc/rstudio` directory in the OOD app session folder to `/etc/rstudio` in the running container, which is the location for RStudio server configuration files. This is one of the directories bound using the `SING_BINDS` variable to collect directories to bind from the host to the container.

While the server is running, individual user sessions will have log data placed in the `rsession.log` file in the OOD app session directory. This behavior is defined in the `rsession.sh` script created in the OOD app session folder by the `script.sh.erb` file. Note that it is not in the template folder, but rather created by a sed command in `script.sh.erb`.

### Authentication

Authentication is handled by the script at `template/bin/auth`, which is put in use as a parameter passed to the `rserver` command in `template/rstudio.script.sh` (with the `--auth-pam-helper-path` flag). The `auth` script must be in the correct location and also be marked as executable in order for authentication to work properly.

### RStudio Server Configuration

The `apptainer exec` command used to launch the Apptainer container binds directories from the host to the container, using the `SING_BINDS` variable to contain those binds. One of those binds links `etc/rstudio` in the OOD app session folder to the `/etc/rstudio` folder in the running container, which is where the RStudio server configuration files are kept. That means that if there's RStudio server behavior that needs to be changed, those changes can be made using that folder within the `template` directory of this repository.
