# GEOS CTM Fixture

## How to build GEOS CTM

### Preliminary Steps

#### Load Build Modules

In your `.bashrc` or `.tcshrc` or other rc file add a line:

##### NCCS

NCCS currently has two different OSs. So you'll need to use different modulefiles depending on which OS you are using.

###### SLES 12

```
module use -a /discover/swdev/gmao_SIteam/modulefiles-SLES12
```

###### SLES 15

```
module use -a /discover/swdev/gmao_SIteam/modulefiles-SLES15
```

##### NAS
```
module use -a /nobackup/gmao_SIteam/modulefiles
```

##### GMAO Desktops
On the GMAO desktops, the SI Team modulefiles should automatically be
part of running `module avail` but if not, they are in:

```
module use -a /ford1/share/gmao_SIteam/modulefiles
```

Also do this in any interactive window you have. This allows you to get module files needed to correctly checkout and build the model.

Now load the `GEOSenv` module:
```
module load GEOSenv
```
which obtains the latest `git`, `CMake`, and `mepo` modules.

#### Obtain the Model

On GitHub, there are three ways to clone the model: SSH, HTTPS, or GitHub CLI.
The first two are "git protocols" which determine how `git` communicates with
GitHub: either through https or ssh. (The latter is a CLI that uses either ssh or
https protocol underneath.)

For developers of GEOS, the SSH git protocol is recommended as it can avoid some issues if
[two-factor authentication
(2FA)](https://docs.github.com/en/github/authenticating-to-github/securing-your-account-with-two-factor-authentication-2fa)
is enabled on GitHub.

##### SSH

To clone the GEOSctm using the SSH url (starts with `git@github.com`), you run:
```
git clone -b vX.Y.Z git@github.com:GEOS-ESM/GEOSctm.git
```
where `vX.Y.Z` is a tag from a [GEOSctm release](https://github.com/GEOS-ESM/GEOSctm/releases). Note if you don't use `-b`, you will get the `main` branch and that can change from day-to-day.

###### Permission denied (publickey)

If this is your first time using GitHub with any SSH URL, you might get this
error:
```
Permission denied (publickey).
fatal: Could not read from remote repository.

Please make sure you have the correct access rights
and the repository exists.
```

If you do see this, you need to [upload an ssh
key](https://docs.github.com/en/github/authenticating-to-github/adding-a-new-ssh-key-to-your-github-account)
to your GitHub account. This needs to be done on any machine that you want to
use the SSH URL through.


##### HTTPS

To clone the model through HTTPS you run:

```
git clone -b vX.Y.Z https://github.com/GEOS-ESM/GEOSctm.git
```
where `vX.Y.Z` is a tag from a [GEOSctm release](https://github.com/GEOS-ESM/GEOSctm/releases). Note if you don't use `-b`, you will get the `main` branch and that can change from day-to-day.

Note that if you use the HTTPS URL and have 2FA set up on GitHub, you will need
to use [personal access
tokens](https://docs.github.com/en/github/authenticating-to-github/accessing-github-using-two-factor-authentication#authenticating-on-the-command-line-using-https)
as a password.

##### GitHub CLI

You can also use the [GitHub CLI](https://cli.github.com/) with:
```
gh repo clone GEOS-ESM/GEOSctm -- -b vX.Y.Z
```
where `vX.Y.Z` is a tag from a [GEOSctm release](https://github.com/GEOS-ESM/GEOSctm/releases). Note if you don't use `-b`, you will get the `main` branch and that can change from day-to-day.

Note that when you first use `gh`, it will ask what your preferred git protocol
is (https or ssh) to use "underneath". The caveats above will apply to whichever
you choose.

---

### Single Step Building of the Model

If all you wish is to build the model, you can run `parallel_build.csh` from a head node. Doing so will checkout all the external repositories of the model and build it. When done, the resulting model build will be found in `build/` and the installation will be found in `install/` with setup scripts like `ctm_setup` in `install/bin`.

#### Building at NCCS (Multiple OSs)

In all the examples below, NCCS builds will act differently. Because NCCS currently has two different OSs, when you use
`parallel_build.csh` you will see that the `build` and `install` directories will be appended with `-SLES12` or `-SLES15` depending
on where you submitted to. When NCCS moves to a single OS again, this will be removed.

Note that if you use the `-builddir` and `-installdir` options, you can override this behavior and no OS will be automatically
appended.

#### Develop Version of GEOS CTM

`parallel_build.csh` provides a special flag for checking out the
development branches of GMAO_Shared and GEOS_Util. If you run:

```
parallel_build.csh -develop
```
then `mepo` will run:

```
mepo develop GMAO_Shared GEOS_Util
```

#### Debug Version of GEOS CTM

To obtain a debug version, you can run `parallel_build.csh -debug` which will build with debugging flags. This will build in `build-Debug/` and install into `install-Debug/`.

#### Do not create and install source tarfile with parallel_build

Note that running with `parallel_build.csh` will create and install a tarfile of the source code at build time. If you wish to avoid
this, run `parallel_build.csh` with the `-no-tar` option.

#### Passing additional CMake options to `parallel_build.csh`

While `parallel_build.csh` has many options, it does not cover all possible CMake options possible in GEOSctm. If you wish to
pass additional CMake options to `parallel_build.csh`, you can do so by using `--` and then the CMake options. Note that *anything*
after the `--` will be interpreted as a CMake option, which could lead to build issues if not careful.

For example, if you want to build a develop Debug build on Cascade Lake while turning on StratChem reduced mechanism and the CODATA
2018 options:

```
parallel_build.csh -develop -debug -cas -- -DSTRATCHEM_REDUCED_MECHANISM=ON -DUSE_CODATA_2018_CONSTANTS=ON
```

As noted above all the "regular" `parallel_build.csh` options must be listed before the `--` flag.

---

### Multiple Steps for Building the Model

The steps detailed below are essentially those that `parallel_build.csh` performs for you. Either method should yield identical builds.

#### Mepo

The GEOS CTM is comprised of a set of sub-repositories. These are
managed by a tool called [mepo](https://github.com/GEOS-ESM/mepo). To
clone all the sub-repos, you can run `mepo clone` inside the fixture:

```
cd GEOSctm
mepo clone
```

The first command initializes the multi-repository and the second one
clones and assembles all the sub-repositories according to
`components.yaml`

#### Checking out develop branches of GMAO_Shared and GEOS_Util

To get development branches of GMAO_Shared and GEOS_Util (a la
the `-develop` flag for `parallel_build.csh`, one needs to run the
equivalent `mepo` command. As mepo itself knows (via `components.yaml`) what the development branch of each
subrepository is, the equivalent of `-develop` for `mepo` is to
checkout the development branches of GMAO_Shared and GEOS_Util:
```
mepo develop GMAO_Shared GEOS_Util
```

This must be done *after* `mepo clone` as it is running a git command in
each sub-repository.

#### Build the Model

##### Load Compiler, MPI Stack, and Baselibs
On tcsh:
```
source @env/g5_modules
```
or on bash:
```
source @env/g5_modules.sh
```

##### Create Build Directory
We currently do not allow in-source builds of GEOSctm. So we must make a directory:
```
mkdir build
```
The advantages of this is that you can build both a Debug and Release version with the same clone if desired.

##### Run CMake
CMake generates the Makefiles needed to build the model.
```
cd build
cmake .. -DBASEDIR=$BASEDIR/Linux -DCMAKE_Fortran_COMPILER=ifort -DCMAKE_INSTALL_PREFIX=../install
```
This will install to a directory parallel to your `build` directory. If you prefer to install elsewhere change the path in:
```
-DCMAKE_INSTALL_PREFIX=<path>
```
and CMake will install there.

###### Create and install source tarfile

Note that running with `parallel_build.csh` will create and install a tarfile of the source code at build time. But if CMake is run by hand, this is not the default action (as many who build with CMake by hand are developers and not often running experiments). In order to enable this at install time, add:
```
-DINSTALL_SOURCE_TARFILE=ON
```
to your CMake command.

##### Build and Install with Make
```
make -jN install
```
where `N` is the number of parallel processes. On discover head nodes, this should only be as high as 2 due to limits on the head nodes. On a compute node, you can set `N` has high as you like, though 8-12 is about the limit of parallelism in our model's make system.

### Run the CTM

Once the model has built successfully, you will have an `install/` directory in your checkout. To run `ctm_setup` go to the `install/bin/` directory and run it there:
```
cd install/bin
./ctm_setup
```

## Contributing

Please check out our [contributing guidelines](CONTRIBUTING.md).

## License

All files are currently licensed under the Apache-2.0 license, see [`LICENSE`](LICENSE).

Previously, the code was licensed under the [NASA Open Source Agreement, Version 1.3](LICENSE-NOSA).
