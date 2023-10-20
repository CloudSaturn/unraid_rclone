# Rclone Mount & Upload Scripts for Plex Users

Collection of scripts to create rclone VFS mounts to allow fast launch times with Plex (or Emby).  

[The main thread for more support](https://forums.unraid.net/topic/75436-guide-how-to-use-rclone-to-mount-cloud-drives-and-play-files/)

## Credits:

- Thanks to [https://github.com/SenpaiBox/](SenPaiBox) and the Unraid community for help in refining the scripts.
- Thanks to [https://github.com/BinsonBuzz/](BinsonBuzz) for giving me a jumping off point.

## Unraid Users Requirements:

* Unraid Version 6.10+ (untested on versions prior)
* Rclone Plugin
  * Installs rclone and allows the creation of remotes and mounts
  * [Support Thread](https://forums.unraid.net/topic/51633-plugin-rclone/)
* mergerFS for UNRAID Plugin
  * Installs rclone and allows the creation of remotes and mounts
  * [Support Link](https://forums.unraid.net/topic/144999-plugin-mergerfs-for-unraid-support-topic/)
* Recommended: Unraid CA User Scripts Plugin
  * Best way to run scripts
  * [Support Thread](https://forums.unraid.net/topic/48286-plugin-ca-user-scripts/)

## Important Notes
Both scripts involve using a local folder alongside either 1 or 2 remote mounts 

They will autocreate the paths and also spin down any containers specified within then start them up again (for my lazy folk)

rclone subfolder mounting is supported in both scripts (basically anything that works with `rclone mount` SHOULD work here)

Container spin up executes in order the order that its listed in with a 5 second delay (to allow for some time just incase) 

When the script exits, All the containers you specify it to run will be shut down (mainly for plex safety)

There is no upload support for this but if you save a file directly in the respect VFS mount it will upload as VFS cache mode is set to `write`
Mini-blurb from rclone docs:
```
--vfs-cache-mode writes
In this mode files opened for read only are still read directly from the remote, write only and read/write files are buffered to disk first.
This mode should support all normal file system operations.
If an upload fails it will be retried at exponentially increasing intervals up to 1 minute.
```

# Executing 

Easiest way is to use the CA User Scripts Plugin

1. Copy whichever script you need (single or multi remote merge)
2. Edit the variables (lines 11-30 on single, lines 11-34)
3. Save Changes
4. Click "Run in Background"
5. ?????
6. Profit?

For scheduling, you can choose what to use, ive choosen at array start up. 
If you would like the script to run every couple of hours and it'll run an insanity check

# Issues?
Make an issue describe the problem :) 

I'll do my best to help

## Advanced Users

The script can be saved anywhere in the system.

To test the script in your setup, use `bash rclone_mount.sh --test` 

The script will actually execute but will stay in the foreground until you exit. Exiting will stop the mounts and listed containers.

You can also use `bash rclone_mount.sh` with options to `start`, `stop`, `status`, `restart`.
Self explainatory stuff. It'll run in the background like it normally would if you don't want to use the CA user script plug or you'd like to make seperate command buttons for each function.



