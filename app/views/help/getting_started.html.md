# emonLight

It's a simple home energy monitor for *Raspberry Pi*, optimized for simplicity and cost effectiveness.
Source code is available at [github](https://github.com/sermore/emonlight).
Features:

* Power usage levels are read from one or more standard energy meters with pulse output
* Power usage is collected and can be sent to your own server running [emonlight-web](http://github.com/sermore/emonlight-web) or to [emonlight demo site](emonlight.reliqs.net). Output for [emoncms.org](http://emoncms.org) is supported too.
Output for [emoncms.org](http://emoncms.org) is supported too.
* Multiple sources and multiple servers are supported
* Able to drive a buzzer for signaling high-level usage with configurable soft and hard thresholds
  * soft threshold: 1 to 3 intermittent beeps signal depending on proximity to time limit; default for soft limit is set to 3300 Wh with a time limit of 3 hours
  * hard threshold: 4 to 6 intermittent beeps signal depending on proximity to time limit; default for hard limit is set to 4000 Wh with a time limit of 4 minutes


## Hardware

* Raspberry Pi
* energy meter with pulse output
* Raspberry's 5V power supply (minimum 1200mA)
* optional buzzer
* wiring for pulse output and buzzer

### Raspberry

Any version will do, software has been developed using a Raspberry B+.

### Energy meter

Any energy meter with pulse output is fine, see some examples below:

* http://www.schneider-electric.com/products/ww/en/4100-power-energy-monitoring-system/4125-basic-energy-metering/61083-acti-9-iem2000-series/
* http://www.tecnoswitch.com/it/component/k2/item/93-contatore-elettronico-di-energia-elettrica-monofase-electronic-single-phase-energy-meter
* http://www.ebay.com/itm/5-65-A-230V-50HZ-din-rail-Energy-meter-voltage-current-active-reactive-power-KWH-/261851378718?pt=LH_DefaultDomain_0&hash=item3cf78ef41e

Information about pulse output can be found here http://openenergymonitor.org/emon/buildingblocks/introduction-to-pulse-counting.

### Buzzer

The buzzer is driven by a simple GPIO 3.3V on/off signal, no PWM handling at this time.
Due to the constraint above, be aware that buzzer must have:

* built-in oscillator
* driven by 3.3V

Here an example of such a buzzer https://www.adafruit.com/products/1536


### Wiring

Pulse output can be directly connected to GPIO pins, be warned that internal pull-up resistance have to be enabled for GPIO pin used.

<table class="table table-nonfluid">
<tr><th> Energy meter </th><th> Raspberry GPIO </th></tr>
<tr><td> S0- </td><td> GND PIN </td></tr>
<tr><td> S0+ </td><td> GPIO PIN </td></tr>
</table>

Default pin for pulse reading is GPIO 17.

Buzzer can be directly connected to GPIO pins.

<table class="table table-nonfluid">
<tr><th> Buzzer </th><th> Raspberry GPIO </th></tr>
<tr><td> PIN - </td><td> GND PIN </td></tr>
<tr><td> PIN + </td><td> GPIO PIN </td></tr>
</table>

Default pin for buzzer is GPIO 3.


## Software

Software is written in C.

Development has been done with [netbeans](www.netbeans.org) connecting to a raspberry B+ device running [Raspbian](http://www.raspbian.org]), but any other distro will do.

The build system is based on Makefile.

Program doesn't require special privileges, When it is executed as a daemon it defaults to use system wide configuration in order to be handled by a debian-compatible sytem installed service.

Raspberry GPIO configuraton must be performed before program can be executed, otherwise it will fail asking for root permission.

Required Libraries:

* [libcurl](http://curl.haxx.se/libcurl/)
* [wiringPi](http://wiringpi.com/)
* [libconfig](http://www.hyperrealm.com/libconfig/)


### Build and install

* connect to your rasperryPi and open a shell
* install software for C compilation
* install git to download the software

install wiringPi library following instruction [here] (http://wiringpi.com/download-and-install/)
	
install libraries

	sudo apt-get install libconfig-dev libcurl4-gnutls-dev 
	
retrieve source code from github

	git clone https://github.com/sermore/emonLight.git

build

	cd emonlight
	make

install system service named *emonlight*

	sudo make install

setup configuration for service; default pins are GPIO 17 for pulse output reading and GPIO 3 for buzzer control; if you need different setup you have to change:

* `/etc/default/emonlight` which contains GPIO pins and queue configuration
* `/etc/emonlight.conf` which contains program settings

start service

	sudo service emonlight start

stop service

	sudo service emonlight stop


#### GPIO configuration
Configuration of GPIO pins must be performed before first program execution.

	# configure input pin for reading pulse signal
	gpio -g mode 17 in
	# enable pull-up resistance for GPIO 17
	gpio -g mode 17 up
	# enable interrupt sensing for falling edge signal on GPIO 17 pin
	gpio edge 17 falling
	# configure output pin for buzzer control 
	gpio -g mode 3 out
        #export above configuration in order to be handled by program without privileges
        gpio export 3 out
	# set to zero level buzzer pin
	gpio -g write 3 0

### configuration file 

`/etc/emonlight.conf` or `$HOME/.emonlight`

    # WARNING this program can drive gpio pins only after pin configuration is made by running gpio 
    verbose = true;
    
    sources = ({
        # gpio pin for pulse signal reading
        pin = 17;
        # number of pulses equivalent to 1 kWh
        pulses-per-kilowatt-hour = 1000;
    }, {
        pin = 3;
        pulses-per-kilowatt-hour = 1200;
    });

    servers = ({
        url = "http://emonlight.reliqs.net";
        protocol = "emonlight";
        map = ({
            pin = 17;
            node-id = 1;
            api-key = "key-3";
        }, {
            pin = 3; 
            node-id = 2;
            api-key = "key-4";
        });
    }, {
        url = "http://emoncms.org";
        protocol = "emoncms";
        map = ({
            pin = 17;
            node-id = 5;
            api-key = "key-1";
        }, {
            pin = 3; 
            node-id = 6; 
            api-key = "key-2";
        });
    });

    # gpio pin to drive buzzer
    buzzer-pin = 3
    buzzer-source = 17
    # power thresholds
    power-soft-threshold = 3300
    # 3 hours
    power-soft-threshold-time = 10800 
    power-hard-threshold = 4000
    # 4 minutes
    power-hard-threshold-time = 240
    
    # if a data-log configuration is found then all data received is saved to this file
    data-log = "/var/lib/emonlight/emonlight-data.log"
    # store of status persistent information: time and count for last pulse received
    data-store = "/var/lib/emonlight/emonlight-data"
