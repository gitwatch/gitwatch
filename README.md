#gitwatch

A bash script to watch a file or folder and commit changes to a git repo

##What to use it for?
That's really up to you, but here are some examples:
* **config files**: some programs auto-write their config files, without waiting for you to click an 'Apply' button; or even if there is such a button, most programs offer you no way of going  back to an earlier version of your settings. If you commit your config file(s) to a git repo, you can track changes and go back to older versions. This script makes it convenient, to have all changes recorded automatically.
* *more stuff!* If you have any other uses, or can think of ones, please let us know, and we can add them to this list!

##Requirements
To run this script, you must have installed and globally available:
* `git` ( [git/git](https://github.com/git/git) | http://www.git-scm.com )
* `inotifywait` (part of **inotify-tools**: [rvoicilas/inotify-tools](https://github.com/rvoicilas/inotify-tools) )