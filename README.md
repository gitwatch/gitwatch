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

##What it does
When you start the script, it prepares some variables and checks if the file [a] or directory [b] given as input really exists.<br />
Then it goes into the main loop (which will run forever, until the script is forcefully stopped/killed), which will:
* watch for changes to the file/directory using `inotifywait` (`inotifywait` will block until something happens)
* wait 2 seconds
* `cd` into the directory [b] / the directory containing the file [a] \(because `git` likes to operate locally)
* `git add <file>`[a] / `git add .`[b]
* `git commit -m"Scripted auto-commit on change (<date>)"`[a] / `git commit -a -m"Scripted auto-commit on change (<date>)"`[b]

Notes:
* the waiting period of 2 sec is added to allow for several changes to be written out completely before committing; depending on how fast the script is executed, this might otherwise cause race conditions when watching a folder
* currently, folders are always watched recursively

##Usage
`gitwatch.sh <file or directory to watch>`<br />
It is expected that the watched file/directory are already in a git repository (the script will not create a repository). If a folder is being watched, this will be watched fully recursively; this also means that all files and sub-folders added and removed from the directory will always be added and removed in the next commit. The `.git` folder will be excluded from the `inotifywait` call so changes to it will not cause unnecessary triggering of the script.

If you want to have the script auto-started upon boot, the method to do this depends on your operating system and distribution. If you have a GUI dialog to set up startup launches, you might want to use that, so you can more easily find and change the startup script calls later on.
A central place to put startup scripts on Linux is generally `/etc/rc.local` (to my knowledge; only tested and confirmed on Ubuntu). This file, if it has the +x bit, will be executed upon startup, **by the root user account**. If you want to start `gitwatch` from `rc.local`, the recommended way to call it is:<br />
`su -c "/absolute/path/to/script/gitwatch.sh /absolute/path/to/watched/file/or/folder" -l <username> &`<br />
The `<username>` bit should be replaced with your username or that of any other (non-root) user account; it only needs write-access to the git repository of the file/folder you want to watch. The ampersand (`&`) at the end sends the launched process into the background (this is important if you have other calls in `rc.local` after the mentioned line, because the `gitwatch` call does not usually return).
Please also note that if either of the paths involved contains spaces or special characters, you need to escape them accordingly; if you don't know how to do that, the internet will help you, or feel free to ask here or contact me directly.

##Feedback
If you have feedback, comments or questions, please feel free to use the full range of interaction: contact me, fork the repo, use the issue tracker, etc. :)