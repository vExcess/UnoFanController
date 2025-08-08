# UnoFanController
PC fan controllers are expensive. Arduinos are cheap (the knockoff ones anyways).

## Background
I bought a Dell prebuilt. The CPU fan gets set to max speed when the CPU is only at 45 degrees. It's REALLY loud. Apparently, this is a known issue with Dells. Unfortunately, because Dell is Dell there is no way to adjust the fan speeds either in the BIOS or even with third party software. I tried swapping out the fan with a quieter one, but it was still too loud. Alas, the only solution is the get a external fan controller. Or rather build my own because fan controllers are expensive.

## Installation
See [Installation Guide](https://github.com/vExcess/UnoFanController/blob/main/installation-guide.md)

## 4-pin PWM Fan Specification
Resource: [https://www.intel.com/content/dam/support/us/en/documents/intel-nuc/intel-4wire-pwm-fans-specs.pdf](https://www.intel.com/content/dam/support/us/en/documents/intel-nuc/intel-4wire-pwm-fans-specs.pdf)

Fan has 4 pins in order from left to right from the perspective of the connector notch being on the right:
1) PWM Pin
    - Purpose: controls fan speed. Higher duty cycle = fan go faster
    - Frequency: 25 KHz (21KHz to 28 KHz is acceptable)
    - Logic Low: 0V (less than 0.8V acceptable)
    - Logic High: 5V (up to 5.25V acceptable)

2) Tachometer Pin
    - Purpose: monitors fan RPM
    - Works by controller applying a voltage less than 12V to the pin. Then the fan pulls the voltage down to 0V twice per rotation.

3) 12V Pin
    - Purpose: powers fan motor

4) Ground Pin

## GUI
The GUI is located at [http://localhost:49942/](http://localhost:49942/)

![gui screenshot](https://raw.githubusercontent.com/vExcess/UnoFanController/refs/heads/main/gui-screenshot.png)