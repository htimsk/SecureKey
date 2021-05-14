# SecureKey
Instructions for using an Aegis Secure Key with Rocket Pool

This guide explains how to configure a Rocket Pool node to store its node wallet, password file, and validator signing keys on an Aegis Secure Key (model 3N or 3NX).  This provides an added layer of security for the home server node operator by placing these files on an AES 256 encrypted USB drive that requires a PIN key to unlock.  The key will be configured so that it will remain unlocked when connected to the server during normal operations, reboots, and powered shutdowns.  When combined with a UPS that will issue commanded shutdowns upon mains power failer conditions, it will remain unlocked so long as standby power is provided to the server. 

A PIN will be required whenever the USB key is disconnected from the server or if the server is unplugged from mains power.  The PIN prevents access to the wallet or signing keys in the event of theft of the server.  It assures that even if the thief plugs in the server, it will not submit attestations on the installed validators, and the node wallet and password file will be inaccessible to the thief without the knowledge of the Aegis Secure Key PIN. 

## Hardeware required

Aegis Secure Key Model 3NX (4 GB) purchased on Amazon for $53 USD. Note

##Installation instructions.

### Configure the Secure Key

1. Setup an Admin password on the DSecureKey following the *First-Time Use* instruction found in the [Aegis User Mannual](https://apricorn.com/content/product_pdf/aegis_secure_key/usb_3.0_flash_drive/ask3_manual_configurable_online_2.pdf) on page 5 

1. Enable *Lock-Override Mode* (see page 20 of the manual). This enables the key to remain unlocked during reboots and powered shutdowns.

1. Unlock the Aegis Key by intering the Admin PIN and plug it into the server within 30 seconds.

### Configure Rocket Pool

1. Stop the Rocket Pool service
```rocketpool service stop```

1.
