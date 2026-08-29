# OOD RStudio App

This repository contains the Open OnDemand configuration for running RStudio Server in an
[Apptainer](https://apptainer.org/) (formerly Singularity) container in HUIT Open OnDemand.

It is based on the [RStudio app from the Ohio Supercomputing Center](https://github.com/OSC/bc_osc_rstudio_server),
with modifications to run with Apptainer in our environment.

The container gives each session a consistent version of R and a consistent set of packages.
Course-specific sub-applications select an image, point R at a shared package library, and enable
optional features such as Slurm access, without a separate container being built for each course.

## Repository layout

```text
build/
    rstudio-base.def          Apptainer definition for the base RStudio image

local/
    generic.yml.erb           The default sub-app
    <course>.yml.erb          Course-specific sub-apps

template/
    script.sh.erb             Main session startup script
    rstudio.script.sh         Starts RStudio Server inside the container
    before.sh.erb             Runs before the session starts
    after.sh.erb              Runs after the session starts
    bin/auth                  Authentication helper
    etc/rstudio/              RStudio Server configuration
    run-r.sh.tmpl             Templates for the generated course batch-job tools
    course-env.sh.tmpl
    README.md.tmpl

README.md                     This file
SLURM.md                      Optional Slurm access from inside the container
STANDALONE_R.md               R installed with Spack, and R package paths
```

This application configuration is more complex than our other setups, so more files need to be in
place for the app to work. In particular there are more files in `template` than is usually the case.
Files in `template` are propagated out to each session of the OOD app, so they are present in the
session directory created when an interactive app runs.

## Container

The base container is defined in `build/rstudio-base.def`. It is a direct translation of a Docker
image from the [Rocker RStudio Docker repo](https://hub.docker.com/r/rocker/rstudio)
([Rocker homepage](https://rocker-project.org/)) into the Apptainer format. The definition file can
be used to change the behavior to suit different use cases.

The image contains R, RStudio Server, the packages installed into the image, and the system libraries
those packages need. It does not contain every service available on the host. Host resources needed by
a session are made available through Apptainer bind mounts when the session starts.

The image a course uses is set in that course's sub-app.

## Course sub-applications

Course-specific configurations live in `local/`, for example `local/stat139.yml.erb`.

A sub-app commonly defines:

- the course name and the Canvas course it is gated to;
- the container image;
- the course-managed R package library path;
- resource requests and limits;
- optional features, such as Slurm access.

### `form:` and `attributes:`

An attribute used by the session templates must be listed under `form:` as well as `attributes:`.

Open OnDemand passes only `form:`-listed values into `context`. An attribute that exists only under
`attributes:` appears to be configured but never reaches the ERB templates. A conditional block
guarded by that attribute then does nothing, with no error and no log line.

A hard-coded value listed under `form:` is still hidden from the user in the dashboard.

## Session directories

When a user launches the app, Open OnDemand creates a session directory. The session card in the OOD
interface links to it under a UUID.

Session directories are located at:

```text
/shared/home/<username>/ondemand/data/<sys|dev>/<app-name>/output/<session-uuid>
```

The variables in that path are as follows:

| Component | Meaning |
|---|---|
| `username` | The NetID username of the user who ran the app |
| `sys` or `dev` | For an app installed system-wide on the portal node at `/var/www/ood/apps/sys`, the session directory appears under `sys`. For sandbox apps set up for an individual user, it appears under `dev` |
| `app-name` | The name of the directory with the app configuration |
| `session-uuid` | A randomly generated unique identifier for the session, visible on the app session card in the OOD interface |

The session directory holds the generated scripts, the logs, and the RStudio Server configuration for
that session.

## Logging

Different phases of the app launch are logged in different locations.

### Startup

`script.sh.erb` sets up the Apptainer spack environment and invokes `rstudio.script.sh`. Both log to
the `output.log` file in the OOD session folder.

These scripts include a `set -x` directive, so the commands that run are written to stdout, which is
directed to `output.log`. Anything printed to stdout in those scripts, `echo` commands included,
appears in `output.log`.

A launch that fails before RStudio opens should be investigated in `output.log` first.

### RStudio Server

When the container and RStudio Server are running, they produce output in the `logs` directory of the
session folder. This behavior is controlled by `template/etc/rstudio/logging.conf.erb`.

That file is used by RStudio Server to configure logging because the Apptainer launch command links
the `etc/rstudio` directory in the OOD session folder to `/etc/rstudio` in the running container,
which is where RStudio Server keeps its configuration files. It is one of the directories bound using
the `SING_BINDS` variable, which collects the directories to bind from the host into the container.

### R sessions

While the server is running, individual user sessions write log data to the `rsession.log` file in the
OOD session directory.

This behavior is defined in the `rsession.sh` script, which is created in the OOD session folder by
`script.sh.erb`. Note that `rsession.sh` is not in the `template` folder. It is created by a `sed`
command in `script.sh.erb`, because it needs session-specific values.

## Authentication

Authentication is handled by the script at `template/bin/auth`. It is put into use as a parameter
passed to the `rserver` command in `template/rstudio.script.sh`, with the `--auth-pam-helper-path`
flag.

The `auth` script must be in the correct location and must be marked as executable. Authentication
does not work otherwise.

## RStudio Server configuration

The `apptainer exec` command used to launch the container binds directories from the host into the
container, using the `SING_BINDS` variable to collect those binds.

One of those binds links `etc/rstudio` in the OOD session folder to the `/etc/rstudio` folder in the
running container, which is where the RStudio Server configuration files are kept.

So RStudio Server behavior that needs to change should be changed in `template/etc/rstudio/` in this
repository. Examples include logging behavior, session settings, and server configuration.

## Course-managed R libraries

A course can install R packages into shared course storage rather than having a new container image
built. Teaching staff can then add or update packages during the term.

The library path is set in the course sub-app and is made available to the RStudio session.

R package paths, how `.libPaths()` behaves, and R installed with Spack are covered in
[STANDALONE_R.md](STANDALONE_R.md).

## Slurm access from inside the container

Slurm access is optional and is enabled per sub-application.

A course that enables Slurm can submit and query Slurm jobs from inside the RStudio container. This
is intended for courses that want students to work interactively in RStudio and submit
longer-running work to the cluster without changing to a different R environment.

Slurm runs on the compute node, outside the container. The container must therefore be given access
to selected host-side resources, including the Slurm client, the Munge authentication socket, and
the user and group identity information Slurm needs to resolve names to numeric IDs.

A course opts in with a single attribute on its sub-app form. Sub-apps that do not opt in launch
unchanged.

The complete architecture, configuration, and troubleshooting are documented in
[SLURM.md](SLURM.md). That document also covers the generated batch-job tools that let a student run
an R script on a compute node using the same image as their RStudio session.

## Where documentation goes

Keep documentation close to the thing it describes:

| Topic | Home |
|---|---|
| General RStudio app behavior | `README.md` |
| Slurm access from inside the container | `SLURM.md` |
| R package paths and R with Spack | `STANDALONE_R.md` |
| What a course requested, how it was set up and tested | The course runbook in [ood-misc-runbooks](https://github.com/Harvard-ATG/ood-misc-runbooks) |

A course page records one course. This repository explains the mechanism that serves every course. A
mechanism described in both places goes stale in one of them the first time the template changes.
