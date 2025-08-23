# Installation Guide

## Required Hardware/Tools
- Arduino Uno R3 (or equivelant knockoff)
- 4-pin PWM fan (3 pin fans not supported)
- electronics wires
- wire stripper (knife or scissors work fine)
- soldering iron (or just twist the wires together)
- electrical tape (regular tape should be fine too)
- cardboard
- hot glue (or more tape)

## Arduino
The Arduino will interact with the fan by controlling its speed and monitoring its RPM.

Wire up your Arduino as shown in the image. Open up the `UnoFanController.ino` file in the Arduino IDE and compile and upload it to your Arduino.

![wiring diagram](https://raw.githubusercontent.com/vExcess/UnoFanController/refs/heads/main/wiring-diagram.png)

## Daemon
The daemon is the part that runs on your computer. It monitors the CPU's temperature, calculates the desired fan speed, and sends the fan speed to the Arduino.

On Linux you will need to download and install libserialport:
```sh
git clone git://sigrok.org/libserialport
cd libserialport/
./autogen.sh
./configure
make
sudo make install
```
If you are using Windows, then serial_port_win32 is used instead which doesn't need to be seperately installed.

Run `dart compile exe src/daemon.dart` to compile the daemon. A `daemon.exe` file will be created which you run the background to control the Arduino.

## GUI
The GUI is the user interface for adjusting the controller. The GUI is a webpage located at [http://localhost:49942/](http://localhost:49942/) that is started by the daemon. The GUI allows the user to monitor the CPUs temperature, fan usage, and fan RPM. In addition the GUI allows the user to manually control the fan speed or set a curve that the daemon will use to automatically adjust the fan speed based on CPU temperature.

![gui screenshot](https://raw.githubusercontent.com/vExcess/UnoFanController/refs/heads/main/gui-screenshot.png)

# Uninstallation
Delete the files you installed plus delete the `.UnoFanController` directory from your home directory.