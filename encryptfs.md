# Instructions for Using eCryptfs with Rocket Pool

This guide explains how to configure a Rocket Pool node to store its node wallet, password file, validator signing keys, and slashing database in an encrypted folder using eCryptfs. eCryptfs is a package of disk encryption software for Linux. Its implementation is a POSIX-compliant filesystem-level encryption layer, aiming to offer functionality similar to that of GnuPG at the operating system level. It has been part of the Linux kernel since version 2.6.19. This provides an added layer of security for node operators by placing these files in a 16-bit AES encrypted folder that requires a manually entered passphrase to unlock. The folder will be configured to remain unlocked during normal operations but will lock during reboots and power loss events.

This setup has a few advantages over the Aegis secure key. They include the ability to unlock the folder remotely and the cost savings of the Aegis hardware. In addition, this can solution can be used by all nodes, like the Raspberry Pi4 nodes that were not able to maintain USB power during reboots.

The node is able to boot unattended. However, a manually-entered passphrase must be provided for the server to resume attesting duties. That passphrase can be remotely provided via SSH or supplied locally via the keyboard. The use of the encrypted data folder prevents access to the wallet and the consensus client validator signing keys in the event of theft of the server. Even if the thief plugs in the server designed to autoboot upon power restoration, the server will not submit attestations on the installed validators. This will assure the node operator that they can reinstall and recover their seeds without fear of having two signing keys triggering a slashing event. Also, the node wallet and password file will be inaccessible to the thief without knowing the passphrase.


### Installation instructions

1. Complete the regular installation of the Rocket Pool node software.

1. Install eCryptsfs. 
    ```
    sudo apt-get install ecryptfs-utils -y
    ```

1. Create a bash script by running `nano RPunlock.sh` and copy the following code into the file. Save the file and exit nano.
    ```
    #!/bin/bash
    # This simple unlocks the RocketPool data directory with ecryptfs

    if mount | grep .rocketpool/data; then
            echo "Data folder already unlocked."
    else
            read -p 'Enter data folder passphrase : ' -s mountphrase
            read -p $'\nRenter the passphrase : ' -s mountphrase2
            echo ""
            if [[ "$mountphrase" == "$mountphrase2" ]]; then
                    sudo mount -t ecryptfs -o key=passphrase:passphrase_passwd=${mountphrase},no_sig_cache=yes,verbose=no,ecryptfs_cipher=aes,ecryptfs_key_bytes=16,ecryptfs_passthrough=no,ecryptfs_enable_filename_crypto=no ~/.rocketpool/data/ ~/.rocketpool/data
            else
                    echo "Passphrases did not match. No action taken."
            fi
    fi

1. Make the RPunlock.sh script executable.
    ```
    chmod u+x RPunlock.sh
    ```

1. Stop the rocket pool service.
    ```
    rocketpool service stop
    ```

1. Move the contents of the data directory to a temporary folder.
    ```
    sudo mv ~/.rocketpool/data ~/.rocketpool/datatemp
    ```

1. Create a new data folder.
    ```
    sudo mkdir ~/.rocketpool/data 
    ```

1. Encrypt the data folder by running RPunlock. 
    ```
    ./RPunlock.sh
    ```
    >  If this is the first time running the script, enter a new passphrase of your choice. <B>Remember your passphrase.</B> You will need to re-enter that every time you want to unlock the encrypted data folder. If you lose this passphase, you can recover all private keys and validator signatures using the 24-word node wallet recovery seed words. 


1. Copy the contents of the old data directory into the newly unlocked encrypted data folder. 
    ```
    sudo mv ~/.rocketpool/datatemp/* ~/.rocketpool/data/
    ```

1. Delete the temporary data folder that is now empty. 
    ```
    sudo rm -r ~/.rocketpool/datatemp
    ```

 1. Restart the Rocket Pool service.
    ```
    rocketpool service start
    ````
<br>
<br>

### Using RPunlock

During power restarts and node reboots, the node OS and Rocket Pool software will start, but the validator keys will not be accessible. During reboots, it will be necessary for the Node Operator to perform the following actions manually. These can be performed either locally on the node or via SSH. 

1. Stop the rocket pool service.
    ```
    rocketpool service stop
    ```

1.  Unlock the encrypted folder running the RPunlock script. Enter the same passphrase as you originally used to encrypt the folder. 
    ```
    ./RPunlock.sh
    ```

 1. Restart the Rocket Pool service.
    ```
    rocketpool service start
    ````

 1. Confirm that the node is functioning normally by watching the event logs for proper attestations using the signing keys.
    ```
    rocketpool service logs eth2
    ````
