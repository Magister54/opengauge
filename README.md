# Dashboard

Super fancy Raspberry Pi based infotainment system mor my car

## Global setup on the Pi

Make sure you are a member of the dialout group:

`$ sudo usermod -a -G dialout pi`

Copy config/dashboard.desktop to ~/.config/autostart

Copy config/start.sh to where config/dashboard.desktop points. Make sure to give the good path to the executable

