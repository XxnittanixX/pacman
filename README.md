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
The configuration of PACMAN is done using JSON files with a loose structure.

PACMAN operates by distinguishing between "properties" and "property groups"
as the configuration system is based on the idea of a key-value store. The
following schema is applied:

	{
		"property1": "value",
		"propertyGroup1": {
			"property2": "value"
		}
	}

`property1` and `property2` are (simple) properties while `propertyGroup1` is
a property group containing `property2` but not `property1`. Deeper structures
are currently not supported by the query commands but might be later.

The main configuration is in the file `config.json` at the root directory.
It contains one property group for each environment. By changing environments,
the global variable `$global:System.Environment` is set to a hashtable with all
properties in the respective node. The property group without a label contains
some system properties needed by PACMAN (e.g. the default environment)
