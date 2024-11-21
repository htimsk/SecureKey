# Instructions for using an Apricorn Aegis Secure Key with Rocket Pool
<br>

<B>Note: There is an alternate method using eCryptfs that does not require the purchase of an Aegis Key. However, issues have been reported when rebooting and having the RP software stack access the \data folder before it has been decrypted on reboot. For this reason, the preferred method is using the Aegis key. See [Instructions for Using eCryptfs with Rocket Pool](encryptfs.md) for more details. </B> 


<br>

This guide explains how to configure a Rocket Pool node to store its node wallet, password file, and validator signing keys on an Aegis Secure Key (model 3N or 3NX).  This provides an added layer of security for the home server node operator by placing these files on an AES 256 encrypted USB drive that requires a PIN key to unlock.  The key will be configured to remain unlocked when connected to the server during normal operations, reboots, and powered shutdowns.  When combined with a UPS that will issue commanded shutdowns upon a mains power failure, it will remain unlocked so long as standby power is provided to the server by the UPS. 

A PIN will be required whenever the USB key is disconnected from the server or if the server is unplugged from mains power.  The PIN prevents access to the wallet and the eth2.0 validator signing keys in the event of theft of the server.  Even if the thief plugs in the server designed to autoboot upon power restoration, the server will not submit attestations on the installed validators.  This will assure the node operator that they can reinstall and recover their seeds without fear of having two signing keys triggering a slashing event. Also, the node wallet and password file will be inaccessible to the thief without knowing the Aegis Secure Key PIN.  The thief will only have six attempts at Brute-Forcing the PIN.

## Hardware required
![](img/secureKey.jpg)

Apricorn Aegis Secure Key Model 3NX (4 GB) purchased on Amazon for $53 USD. Note: Any capacity drive will do as you will be storing only a few kilobytes worth of information.  You can order either a USB 3.0 connector (3NX) or a USB C connector (3NXC). The USB drive slot must remain powered during a shutdown. Yellow (they look orange to me) colored USB-A ports, and most USB C continue to provide power when the server is turned off. For my use case, I used a 3NX connected to a rear-facing USB C (Thunderbolt) slot on my server via and USB-A to USB-C dongle.

<b> Note for Rasberry Pi4 nodes: </b> I am not yet aware of a mechanism to configure the USB ports on the Pi4 to remain powered on during a reboot. If anyone has a solution to configure a port to continue to provide power during a soft reboot, please share it with the community.  


## Installation instructions

### Configure the Secure Key

1. Setup an Admin password on the Secure Key following the *First-Time Use* instruction found in the [Aegis User Mannual](https://apricorn.com/content/product_pdf/aegis_secure_key/usb_3.0_flash_drive/ask3_manual_configurable_online_2.pdf) on page 5 
1. Enable *Lock-Override Mode* (see page 19 of the manual). This enables the key to remain unlocked during reboots and powered shutdowns.
1. Set the number of brute-force attempts to 6 by following the *Brute-Force Protection* instruction on page 14. Set the number of before/after attempts to 3 as this is consistent with a Ledger-like hardware wallet. 
1. Unlock the Aegis Key by entering the Admin PIN and plug it into the server within 30 seconds.

<br>

### Format the Secure Key


1. Find the device name: 
    ```
    sudo fdisk -l
    ```
    The Disk model will be titled *Secure Key 3.0*. Note the Device name assigned to the drive. In the example below, it is `/dev/sda1`.
    <br>
    
    ![](img/fdisk.jpg)
1. Choose the GPT partitioning standard: 
    ```
    sudo parted /dev/sda mklabel gpt
    ```
1. Once the format is selected, you can create a partition spanning the entire drive by typing: 
    ```
    sudo parted -a opt /dev/sda mkpart primary ext4 0% 100%
    ```
1. Now that we have a partition available, we can format it as an Ext4 filesystem. To do this, pass the partition to the mkfs.ext4 utility: 
    ```
    sudo mkfs.ext4 /dev/sda1
    ```
    > Note: Make sure you pass in the partition and not the entire disk. In Linux, disks have names like `sda`, `sdb`, `hda`, etc. The partitions on these disks have a number appended to the end. So we would want to use something like `sda1` and not `sda`.
 <br>
 
 ### Mount the Secure Key

1. Create a /key subdirectory under the default ~/.rocketpool directory to mount the Secure Key
    ```
    sudo mkdir ~/.rocketpool/key
    ```
1. Use blkid to determine the UUID entry for the Aegis key:

    ```
    sudo blkid
    ```
1. Copy the UUID string delivered, and then use it without quotes in /etc/fstab (`sudo nano /etc/fstab`) by adding the following line to the bottom of the /etc/fstab file and save. Replace USERNAME with the username where the /.rocketpool directory was installed. Replace the XXXX with your Aegis key UUID. This will ensure that the Aegis key is mounted to the correct directory on each boot. Use of UUID ensures that the fstab entry will always point to the correct drive, even if other drives are connected or removed.
    ```
   UUID=XXXXXXXX-XXXX-XXXX-XXXXXXXXXXXX /home/USERNAME/.rocketpool/key ext4 defaults 0 2
    ```
1. Mount the filesystem now by typing:
    ```
    sudo mount -a
    ```
<br>

### Configure Rocket Pool (Versions 1.3 and later)

1. Stop the Rocket Pool service:
    ```
    rocketpool service stop
    ```
1. Move the data folder into the key mount:
    ```
    sudo mv ~/.rocketpool/data ~/.rocketpool/key/
    ```

1. Run the Rocket Pool configuration service:
    ```
    rocketpool service config
    ```
    
1. Navigate to "Smartnode and Tx Fees" and press [Enter] to edit that submenu.

1. Navigate to "Data Path" and edit that to include the new Aegis file path by instering "/key" so that the entry reads "~/.rocketpool/key/data". Press [Enter] to save that line.  See the image below.
![](img/settings.jpg)

1. Navigate to "Review Changes and Save." Save and exit. The Rocket Pool configuration service will automatically restart the services upon exit. 

1. Verify that the installation was successful by checking your node status:
    ```
    rocketpool node status
    ```
<br>
<br>
<br>
<br>

***
