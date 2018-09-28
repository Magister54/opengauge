# Base updates
sudo apt update
sudo apt upgrade
sudo apt dist-upgrade
sudo rpi-update

# Packages to install
sudo apt install at-spi2-core

# Raspberry pi GL config

## GL driver
This will make app run smoother

sudo raspi-config

### Change GL driver
7 - Advanced Options
A7 GL Driver
G2 GL (Fake KMS)

### Allow more ram for graphics
7 - Advanced Options
A3 Memory Split
256

## Screen turn-off disable
Open /etc/lightdm/lightdm.conf and add the following line

xserver-command=X -s 0 -dpms

# Qt version 5.11.1 mandatory

Top build:

$ cmake .. -DCMAKE_PREFIX_PATH=/home/pi/Downloads/usr/local/Qt-5.11.1

where the path corresponds to where QT 5.11 is installed

Also make sure qt.conf is next to the executable and points to the installation of QT:

'''
[Paths]
Prefix = /home/pi/Downloads/usr/local/Qt-5.11.1
'''

# Build on other system for testing

cmake .. -DOFF_PLATFORM_TEST_BUILD:bool=true
