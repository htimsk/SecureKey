# SecureKey
Instructions for using and Aegis Secure Key with Rocket Pool

This guide explains how to configure a Rocket Pool node to store its node wallet, password file and vallidator signing keys on and Aegis Secure Key (model 3N or 3NX). This provides and added layer of sercurirty for the home server node operator by placing these files on an AES 256 encrypted USB drive that requires a PIN key to unlock. The key will be configured in such a way that it will remain unlocked when connected to the the server during normal opetations, reboots, and powered shutdowns. When combined with a UPS that will issue commanded shutdowns upon mains power failer conditions it will remain unlocked so long as standby power if provided to the server. 

A PIN will be required when ever the USB key is disconected from the server or if the server is unpluged from mains power. This is usefull to prevent access to the wallet or singing keys in the event of theft of the server. It assures that even if the server is plugges in by the theif it will not be able to submit attestations on the installed validaors and the node wallet and passord file will be inaccessable to the theif with out the knowledge of the Aegis Secure Key PIN. 

Installation instructions.
