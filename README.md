# PACMAN - Package Manager
PACMAN is a repository-based, package-focused developer shell. It supports the 
developer by automating package initialization, building, publishing and version
management.

## Installation
The installation of PACMAN usually happens before creating a new source code
repository. Simply open up a PowerShell, change into the directory you want to
create your repository in, and enter the following command:

	iwr https://raw.githubusercontent.com/xyrus02/pacman/master/tools/pacman/InstallShell.ps1 | iex

This command will execute the content of the file behind the above URL. Even 
though I know the script is safe, I generally advise you to check the content
before executing.

## Usage
After installation, the shell can be accessed with the file `shell.cmd`. This
script will open up a new PowerShell in which the PACMAN environment is loaded.
If you already have an existing PowerShell or you need to run some PACMAN 
commands in a headless environment (e.g. a build server or a Docker container),
you can simply run the script

	tools\pacman\LoadEnvironment.ps1
	
in the PowerShell instance of your choice. After running the script above, your
shell has all the PACMAN commands available and the global variables are 
properly set.

### Commands
This section is currently being written. Please stay tuned!

## Configuration
The configuration of PACMAN is done using XML files with the extension "props".
These files share the MSBuild namespace and can theoretically be included in
MSBuild projects. However, PACMAN does not necessarily require MSBuild to 
operate. 

Each node in a `PropertyGroup` is a property. The text inside the node is the
value. The `Label` attribute of a property group is used to allow different
propert scopes in a single configuration file. This usage of `Label` is not
consistent with MSBuild behavior and needs to be kept in mind when including
configuration files in MSBuild projects!

The main configuration is in the file `config.props` at the root directory.
It contains one property group for each environment. By changing environments,
the global variable `$global:System.Environment` is set to a hashtable with all
properties in the respective node. The property group without a label contains
some system properties needed by PACMAN (e.g. the default environment)
