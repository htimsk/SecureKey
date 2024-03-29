# Instructions for using dm-crypt/LUKS with Rocket Pool

This guide explains how to configure a Rocket Pool node to store its configuration
directory (e.g. `~/.rocketpool`) in an encrypted LUKS "file container".

This provides an added layer of security for node operators by keeping all Rocket
Pool configuration assets encrypted.

We describe a manual unlock scheme, where the node operator must log 
in into the node and enter the decryption key on every boot.

### Setup encrypted LUKS container

1. Download the LUKS container creation script:
    ```shell
    curl -LO https://raw.githubusercontent.com/htimsk/SecureKey/main/scripts/create-luks-container.sh
    chmod +x create-luks-container.sh
    ```

1. Create a LUKS container
    ```shell
    sudo ./create-luks-container.sh manual vault 2GiB
    ```

1. Unlock the LUKS container

    **Note**:
      * **You will need to run this step every time the node reboots**
      * Docker will not start until the LUKS container is unlocked

     ```shell
     sudo /var/lib/luks/.containers/vault/unlock.sh
     ```

### Move configuration files to the encrypted mount point

1. Complete the regular installation of the Rocket Pool node software.

1. Start and enable the encrypted LUKS container
    ```shell
    sudo systemctl enable --now mount-vault.service
    ```

1. Stop the Rocket Pool service
    ```shell
    rocketpool service stop
    ```

1. Transfer the configuration files to the encrypted mount point
    ```shell
    sudo chown ${USER} -R /var/lib/luks/vault/
    mkdir -m 0700 /var/lib/luks/vault/rocketpool
    sudo cp -a ~/.rocketpool/* /var/lib/luks/vault/rocketpool/
    mv ~/.rocketpool ~/.rocketpool.bak # We will remove this later
    ln -s /var/lib/luks/vault/rocketpool ~/.rocketpool
    ```

1. Start the Rocket Pool Service
    ```shell
    rocketpool service start
    ```
 
 1. Confirm that the node is functioning normally by watching the event logs for proper attestations.
    ```shell
    rocketpool service logs eth2
    ````

1. If everything is working correctly, remove the old configuration files
    ```shell
    sudo apt-get install secure-delete
    sudo srm -r ~/.rocketpool.bak
    ```

## Removing the LUKS container

**WARNING**: here be dragons. Be careful to not remove a LUKS container currently in use by Rocket Pool.

Removing the encrypted container will destroy all data stored inside it. Make sure you have copies of any important data you wish to keep.

```shell
sudo systemctl disable --now mount-vault.service
sudo rm /etc/systemd/system/mount-vault.service
sudo umount /var/lib/luks/vault > /dev/null 2>&1
sudo cryptsetup luksClose vault > /dev/null 2>&1
sudo rm -r /var/lib/luks/.containers/vault
```
