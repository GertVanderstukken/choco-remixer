## What is this?

This automates some tasks involved in maintaining a private Chocolatey repository, specifically focusing on repositories hosted on Nexus.

- Checking for packages that out of date in a Nexus NuGet repository, and updating them.

- Moving packages from a Nexus proxy repository to a hosted Nexus repository.

- [Internalizing/Recompiling](https://chocolatey.org/docs/how-to-recompile-packages) select Chocolatey packages, otherwise known as embedding the binaries inside the package.

## Requirements

- PowerShell v5.1+ - Primarily used so far on Windows, should work fine with Linux, but I have not thoroughly tested it yet.
- `choco` installed and on your path
- A nuget repository or a folder with `.nupkg`s to internalize. Nexus is the repository that I use and test with.
	- Drop path's are available with ProGet only
	- RepoMove and RepoSearch are Nexus only

## Setup

- Clone this repository
- Chocolatey is required, make sure that it is installed and working properly.
- Copy `*.xml.template` files to `*.xml` and edit them.
    - See the files for comments about each of the options.
- The path to each of these files can be specified as such (in order of precedence):
    1. Manually with the `-configXML`, `-internalizedXML`, and `-repoCheckXML` arguments to the locations of these files.
    2. Manually with the `-folderXML` argument which specifies the location to a folder with all three files.
    3. Then if neither of those is specified, the folder that contains the `choco-remixer.psm1` module will be checked.
    4. Then the parent folder of the module will be checked.
    5. Finally, the `$env:AppData\choco-remixer` folder will be checked (`$env:HOME/config/choco-remixer` on Linux)
- If you are using the automatic pushing (`pushPkgs`), make sure `choco` has the appropriate `apikey` setup for that URL.
- It is a good idea to put the xml files in a git repository.

## Operation

- Import the `choco-remixer` PowerShell module
- Run `Invoke-InternalizeChocoPkg`

- If you have `useDropPath` and `pushPkgs` disabled, the internalized packages are located inside the specified `workDir`.
- If you have `writePerPkgs` disabled, add the package versions to `internalized.xml` under the correct IDs. Otherwise, it will try to internalize them again.

- If continuously re-running for development or bug fixing, use the `-skipRepoCheck` switch, so as to not get rate limited by chocolatey.org

## Adding support for more packages

See [ADDING_PACKAGES.md (in progress)](https://github.com/TheCakeIsNaOH/choco-remixer/blob/master/ADDING_PACKAGES.md) for more information on how to add support for another package. PRs welcome, see [CONTRIBUTING.md](https://github.com/TheCakeIsNaOH/choco-remixer/blob/master/CONTRIBUTING.md) for more information

Otherwise, open an [issue](https://github.com/TheCakeIsNaOH/choco-remixer/issues/new) to see if I am willing to add support.


## Why have internalization functionality?

- Because relying on software to be available at a specific URL on the internet in perpetuity is not a good idea for a number of reasons.
- Manually downloading and internalizing for each individual package version is huge amount of work for any quantity of packages.
- Allows (most) packages to work on offline/air gapped environments.
- Makes install a previous version always possible. Some software vendors only have their latest version available to download, in which case old package versions break.

## Why this is better than the Chocolatey official internalizer

In comparison with the [Chocolatey business license](https://chocolatey.org/pricing#faq-pricing) that has [automated internalization functionality](https://chocolatey.org/docs/features-automatically-recompile-packages), choco-remixer:

- Is free and open source software
- Is available at no cost, instead of starting at $650/year, which is out of reach for almost all non-business users.
- Does not require a licensed Chocolatey installation to install the internalized packages. Packages internalized with the licensed internalizer stop working if you license lapses.
- Validates checksums of downloaded binaries (`.nupkg`s included) and warns if checksums are not available in the package.
- Is available for Linux systems.

## Caveats

- This is not at a stable release. Things may break, feel free to open an issue if I broke something.
- Packages can change on the Community Repository, again, open an issue if a package is broken.
- Packages are supported by whitelist, and support must be added individually for each package.

## Specific TODOs

- Add support for internalizing package icons
- Comment based help for all public functions, specifically in `Edit-InstallChocolateyPackage` (platyps?)
- Module metadata creation, module install, other helper scripts
- Add a helper where a single Chocolatey package can be passed in as a path and internalized
- Complete the components for module, and publish the module (PowerShell gallery?)
- Add Pester tests

## Continuous TODOs

- Better verbose/debug and other information output.
- Generalize and factor out repeated code into functions.
- Continue adding support for more packages

![Progress](https://progress-bar.dev/1817/?scale=6969&width=400&suffix=/6969)

## Potential things to add
- Git integration for personal-packages.xml
- Multiple personal-packages.xml files (for now it probably is best to add an alias to your profile for each xml)
- Async/Parallelize file searching, copying, packing, possibly downloading
- Ability to bump version of nupkg (aka fix version)