# SecureKey
Instructions for using an Aegis Secure Key with Rocket Pool

This guide explains how to configure a Rocket Pool node to store its node wallet, password file, and validator signing keys on an Aegis Secure Key (model 3N or 3NX).  This provides an added layer of security for the home server node operator by placing these files on an AES 256 encrypted USB drive that requires a PIN key to unlock.  The key will be configured so that it will remain unlocked when connected to the server during normal operations, reboots, and powered shutdowns.  When combined with a UPS that will issue commanded shutdowns upon mains power failer conditions, it will remain unlocked so long as standby power is provided to the server. 

A PIN will be required whenever the USB key is disconnected from the server or if the server is unplugged from mains power.  The PIN prevents access to the wallet or signing keys in the event of theft of the server.  It assures that even if the thief plugs in the server, it will not submit attestations on the installed validators, and the node wallet and password file will be inaccessible to the thief without the knowledge of the Aegis Secure Key PIN. 


