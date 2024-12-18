# OOD RStudio App for HUIT OOD

This is an overview of managing R environments in HUIT OOD, namely how R interacts with Spack. Installing R via spack is the way that we make R available for use in HPC scripts. We can also make R code available in containers, but this doesn't make it available for use in slurm jobs, at least not without a lot of unnecessary overhead that will complicate things.

## R Package Paths

When R is installed with spack, the default path for library installations is in the Spack install path, which is not writable to users (unless they're using a course shared folder version of Spack). Users can still install packages, just not in that shared path. This can happen because R can define multiple library paths, with a similar function to a PATH environment variable.

To inspect the library paths that an R session will use, one can launch an R session from the terminal with `R`, and run `.libPaths()` in the R session to see the available paths.

If a user is prompted to create a personal library to install a package, and they accept, R will create a library file within nested folders based in `~/R`. The path will include the system and the R version. If that path exists in the user's home directory, it will be added to the `.libPaths()` automatically.

Other paths can be added to the `.libPaths()` through other means. An overview of different config options can be found in a [Posit help article about R config options](https://support.posit.co/hc/en-us/articles/360047157094-Managing-R-with-Rprofile-Renviron-Rprofile-site-Renviron-site-rsession-conf-and-repos-conf). For us, the most relevant file to alter user behavior is `~/.Rprofile`, which can contain R code that will be sourced to modify R's behavior. Here, we can modify the `.libPaths()` with a line of R code, like `.libPaths(c("/path/to/existing/folder", .libPaths()))`. The R session will use that path to look for libraries, allowing support staff and instructors to install packages to the course shared folder, and students to access the path with a single line of terminal code: `echo '.libPaths(c("/path/to/existing/folder", .libPaths()))' > ~/.Rprofile`

In the case of BST 262, the command to create an .Rprofile file is

```bash
echo '.libPaths(c("/shared/courseSharedFolders/144013outer/144013/R/x86_64-pc-linux-gnu-library/4.4", .libPaths()))' > ~/.Rprofile
```

## R Package Installs

R package installs can work in a user home directory, or in a shared directory when the `libPaths()` are set up properly. However, R package installs can also have external dependencies. These external dependencies will come up when installing a package, like the need for `gdal` when installing the R package `raster`. In that case, when R is installed with Spack, the additional depencencies should also be installed with Spack to the same environment where R is installed, providing access to the software.

However, sometimes this isn't enough. In the case of installing `raster`, the dependent package `terra` failed to install because it wasn't able to locate the library files for either `libproj` or `sqlite3`, both of which were installed as Spack packages to the environment via the spack packages `proj` and `sqlite` (see the bst262 spack environment file). I found a [GitHub issue with other people describing the same problem](https://github.com/r-spatial/sf/issues/1471#issuecomment-2148767638), and adapted the install line to `install.packages('terra', configure.args=c("--with-sqlite3-lib=/shared/spack/opt/spack/linux-amzn2-skylake_avx512/gcc-14.1.0/sqlite-3.46.0-qxr7hpygeupogc6rx745sfsfa2ykhws4/lib"))`. It seems that when using `install.packages()` in R, the `configure.args` argument can be used to pass flags to the installer. I got the flag from the GitHub issue, so I'm not sure if there's a way to determine what flags are available in other installers. Another option might be modifying the `LD_LIBRARY_PATHS` variable outside of R, if a similar issue arises and a similar flag for the installer can't be found. In any case, installing the problem dependency with the additional flag worked, which allowed the `raster` package to be installed. Note that passing the additional flag directly to the `raster` install didn't work.

As for the path to the `lib` directory for the `sqlite` dependency installed via spack, that was found with a `spack find -p sqlite` command, which prints out the install path for spack packages. Running `spack find -p` gets all of the paths, and adding a package name limits the output to that package.
