# Homescripts README

This is my configuration that works for me the best for my use case of an all in one media server. This is not meant to be a tutorial by any means as it does require some knowledge to get setup. I'm happy to help out as best as I can and welcome any updates/fixes/pulls to make it better and more helpful to others.

[Change Log](https://github.com/animosity22/homescripts/blob/master/Changes.MD)

## Home Configuration

- Verizon Gigabit Fios
- Google Drive with encrypted media folder
- Ubuntu 20.04
- Intel(R) Core(TM) i7-7700 CPU @ 3.60GHz
- 32 GB of Memory
- 250 GB SSD Storage for my root
- 1TB SSD for rclone Disk Caching
- 6TB mirrored for staging

## My Workflow

I use Sonarr and Radarr in conjuction with NZBGet and qBittorrent to get my media. 

My normal flow is that they grab a file, download it and place it in `/gmedia` under the correct spot of `/gmedia/TV` `/gmedia/Movies`, that is locally stored underneath the covers.

Every night, a rclone upload scripts moves files from local to my Google Drive. To achieve this, I use rclone to mount my Google Drive and mergerfs to combine a local disk and Google Drive together to provide a single access point for all services.

## rclone and MergerFS

### Installation
My Ubuntu setup:

```
[felix@gemini ~]$ lsb_release -a
No LSB modules are available.
Distributor ID:	Ubuntu
Description:	Ubuntu 20.04 LTS
Release:	20.04
Codename:	focal
```

Fuse needs to be installed for a rclone mount to function. `allow-other` is for my use and not recommended for shared servers as it allows any user to see a rclone mount. I am on a dedicated server that only I use so that is why I uncomment it.

```
$ sudo apt install fuse
```
	
You need to make the change to /etc/fuse.conf to `allow_other` by uncommenting the last line or removing the # from the last line.

	sudo vi /etc/fuse.conf
	root@gemini:~# cat /etc/fuse.conf
	# /etc/fuse.conf - Configuration file for Filesystem in Userspace (FUSE)
	
	# Set the maximum number of FUSE mounts allowed to non-root users.
	# The default is 1000.
	#mount_max = 1000

	# Allow non-root users to specify the allow_other or allow_root mount options.
	user_allow_other
	
After fuse is installed, I install mergerfs. I would grab the proper package from the GitHub repository as packages from default are out-of-date.

My use case for mergerfs is that I always want to write to the local disk first and all my applications (Sonarr/Radarr/Plex/Emby/any application) all point directly to `/gmedia`.
For them it's not relevant if the file is local or remote as they should act the same. 

  	/gmedia
        /local (local mirror disk)
        /GD (rclone mount)
  

My `rclone.conf` has an entry for the Google Drive connection and and encrypted folder in my Google Drive called `media`. I mount media with a rclone script to display the decrypted contents on my server. 

My rclone looks like: [rclone.conf](https://github.com/animosity22/homescripts/blob/master/rclone.conf)

This is my current rclone.service file which has the mount settings documented in it [rclone.service](https://github.com/animosity22/homescripts/blob/master/systemd/rclone.service)

They are all mounted via systemd scripts. rclone is mounted first followed by the mergerfs mount.

My gmedia starts up items in order:
1) [rclone service](https://github.com/animosity22/homescripts/blob/master/systemd/rclone.service) This is a standard rclone mount, the post execution command allows for the caching of the file structure in a single systemd file that simplies the process.

2) [mergerfs service](https://github.com/animosity22/homescripts/blob/master/systemd/gmedia.service) This needs to be named the same as the mount point for the mount to work properly. I use `/gmedia` so the file is named accordingly.


### mergerfs configuration
This is located over here if you want to request help or compile from source [mergerfs@github](https://github.com/trapexit/mergerfs).

I found unionfs to not do what I wanted and I can't stand the hidden files so for my use, it's much easier to configure and use mergerfs.

The following options always write to the first disk in the mount as with post 2.25 there are some changes with the settings so I had to add a few things that were default before.

```bash
-o rw,use_ino,allow_other,func.getattr=newest,category.action=all,category.create=ff,cache.files=partial,dropcacheonclose=true
```

Important items:

- `use_ino` is for hard linking with Sonarr/Radarr.
- `cache.files=auto-full` uses memory for caching and helps out a bit if you have extra memory to spare.
- `category.action=all`, `category.create=ff` says to always create directories / files on the first listed mount point and for my configuration that is `/data/local`
- if you are reading directly from your rclone mount, you don't need to worry about any of mergerfs' settings.

## Scheduled Nightly Uploads

I move my files to my GD every night via a cron job and an [`upload cloud`](https://github.com/animosity22/homescripts/blob/master/scripts/upload_cloud) script. This leverages an [`excludes`](https://github.com/animosity22/homescripts/blob/master/scripts/excludes) file which gets rid of unwanted partial files and my torrent folder.

This is my cron entry:

```
# Cloud Upload
12 3 * * * /opt/rclone/scripts/upload_cloud
```

This is my only upload to my Google Drive minus subtitles. This happens at ~700GB per day, just enough to not hit the 750GB daily upload quota that is published by Google.

## Plex Tweaks
If you have a lot of directories and files, it might be helpful to increase the file watchers by adding this to your `/etc/sysctl.conf` and rebooting. I chose the number below as I wanted to have plenty of headroom over the default option.

```
# Plex optimizations
fs.inotify.max_user_watches=262144
```

These tips and more for Linux can be found at the [Plex Forum Linux Tips](https://forums.plex.tv/t/linux-tips/276247).

## Reducing API Usage / Save Download Quota
There are a number of things I make sure are off in my setup to ensure that my API calls are lower and that I do not hit the download quotas for the day.

### Plex
- `Enable Thumbnail previews` - off: This creates a full read of the file to generate the preview and is set per library that is setup
- `Perform extensive media analysis during maintenance` - off: This is listed under Scheduled Tasks and does a full download of files and is ony used for bandwidth analysis when streaming.

### Sonarr/Radarr
- `Analyze video files` - off: This also fully downloads files to perform analysis and should be turned off as this happens frequently on library refreshes if left on.

## Caddy Proxy Server

I use Caddy to server majority of my things as I plug directly into Google Authentication oAuth2 for authentication. I can toggle CDN on and off via the proxy in the DNS.

My configuration is [here](https://github.com/animosity22/homescripts/blob/master/PROXY.MD).

## Wireguard Configuration

For all my private traffic, I use [TorGuard](https://torguard.net/) as they support port forwarding and have very good support. I recently changed from OpenVPN to Wireguard as it is an easier setup and more effecient.

[Setup and Configuration](https://github.com/animosity22/homescripts/blob/master/WIREGUARD.MD).
