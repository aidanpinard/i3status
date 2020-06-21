# i3 status bar

This is a sample code to help you to build your personnal i3 bar.

![i3status](i3status.jpg)

It comes with :

- public IP address
- local IP address
- crypto-currencies
- VPN on/off (sample with ProtonVPN)
- disk usage
- memory usage
- CPU usage
- date and time
- volume information
- battery information

## Install

In your `~/.config/i3/config` file, add the path to the script `mybar.sh` :

```bash
bar {
  status_command exec /home/you/.config/i3status/mybar.sh
}
```

Replace `/home/you` in this project with your home path.

Copy the files from this `i3status` repository directory to `~/.config/i3status`.

Please, check and modify each script as it is given as an example working actually on Arch Linux (You may not have ProtonVPN, and you need to set you city for the weather informations...)

Restart i3 : `MOD4+SHIFT+R`.

You may also need to install, i.e. for Arch Linux :

```bash
yay -S pamixer # for volume information
yay -S pacman-contrib # for checkupdates, to count available packages
yay -S ttf-font-awesome # for icons
pip3 install psutil --user # for cpu, memory, disk usage
```

## Documentation

- <https://i3wm.org/docs/i3bar-protocol.html>
- <https://i3wm.org/i3status/manpage.html>
- <https://github.com/i3/i3status/tree/master/contrib>
- <https://fontawesome.com/cheatsheet?from=io>