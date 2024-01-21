---
title: On-Demand Activation with System-D Sockets
date: 2022-03-09
description: On demand activation with systemd-sockets
---

<div style="background-color: #30df56 !important;
            color: black;
            font-weight: bold;
            padding: 20px;
            margin: 10px;
            text-align: center;
            font-family: monospace;">
  Easy Difficulty
</div>

In this article I will showcase a template to activate an arbitrary application once it is accessed and deactivate it again automatically if it’s no longer used. While this is not difficult per se, it unfortunately requires a number of systemd units and can be confusing at first. If you only want the code go to my [GitHub](https://github.com/FAUSheppy/systemd-socket-activation-template).

## Overview

![Systemd Socket Activation Overview](/systemd_sockets.png)

## Actual service
Assuming we have a file `/usr/bin/application.sh` that runs continuously once started and provides a service on a Unix or network socket, we first need a systemd unit that starts this program.

	[Unit]
	Description=ScriptWapper
	Requires=check-deactivate.service

	[Service]
	Type=simple
	ExecStart=/usr/bin/application.sh
	ExecStop=pkill application

	[Install]
	WantedBy=multi-user.target
	Systemd socket proxy

We now need a systemd managed socket which can proxy connections, meaning forward thus connections from the systemd socket to the actual applications once they are activated. Some programs don’t need this intermediary and support systemd sockets directly, but many don’t.

	[Unit]
	Description=Socket Proxy for script-wrapper
	After=script-wrapper.service
	Requires=script-wrapper.service

	[Service]
	ExecStart=/lib/systemd/systemd-socket-proxyd 127.0.0.1:ANYPORT

	[Install]
	WantedBy=multi-user.target
	Systemd socket
	
Then we need the actual systemd socket that kicks off every other unit once a it receives a connection attempt.

	[Unit]
	Description=Socket activator for application.sh
	PartOf=script-wrapper-proxy.service

	[Socket]
	ListenStream=ANYPORT
	BindIPv6Only=both
	Accept=false

	[Install]
	WantedBy=multi-user.target

## Checking deactivation condition
A *“type simple”* systemd-service expects the program to run continuously until stopped. It would be nice if our script would just *“know”* by itself, if it can stop. However if you apply this solution to an existing application it might be preferable to have an external, second script which is regularly called to check if the service should continue. For this we need a systemd-timer and unfortunately, because a timer can't call a script, but only another Unit, we also need a wrapper for the script just like for our `application.sh`.

In our case we call this unit `check-deactivate.service` and put as a requirement of our `ScriptWrapper.service` to start it, as soon asm the *ScriptWrapper* unit is started.

The script is expected to stop once it has finished checking the status and act accordingly (meaning stopped the service or let it run). It therefore should be of type *oneshot*.

	# /usr/bin/checker.sh
	if [ users -gt o]
	    systemctl stop ScriptWrapper
	
	-----------------------------------------
	
	[Unit]
	Description=check if unit can be stopped

	[Service]
	Type=oneshot
	ExecStart=/usr/local/bin/checker.sh
	
And the timer with correct dependencies:

	[Unit]
	Description=call checker-service
	After=script-wrapper.service
	PartOf=script-wrapper.service

	[Timer]
	OnUnitActiveSec=15min
	OnActiveSec=14min
	Persistent=false
	Unit=script-wrapper-checker.service

## Other Considerations
### Timeouts
Depending on how long the application needs to start, it might be that the client side application perceives the connection attempt as a timeout. This essentially means that the client has to reinitiate the connection, which might be perceived as bad user experience in some cases.

### Costs of start and stop
Starting and stopping some applications may not fare well against just letting it idle. Consider carefully if the saved idle time is worth the activation and deactivation costs.

### Racecondition between shutdown and startup request
If a request is made during the servers services shutdown, the service will not restart. This could be circumvented, by having a startup script capable of waiting for the shutdown. Though, even if this does happen, it only means a client has to do another connection attempt.

<sup style="font-style: italic;">by Yannik Schmidt</sup><br>
<sup>**Tags:** _Linux, Systemd-D, Sockets</sup>
