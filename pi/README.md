# Base updates
sudo apt update
sudo apt upgrade
sudo apt dist-upgrade
sudo rpi-update

# Packages to install
sudo apt install at-spi2-core

# Qt version 5.11.1 mandatory

Top build:

$ cmake .. -DCMAKE_PREFIX_PATH=/home/pi/Downloads/usr/local/Qt-5.11.1

where the path corresponds to where QT 5.11 is installed

Also make sure qt.conf is next to the executable and points to the installation of QT:

'''
[Paths]
Prefix = /home/pi/Downloads/usr/local/Qt-5.11.1
'''
