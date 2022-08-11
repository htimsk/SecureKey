# Instructions for using dm-crypt/LUKS with Rocket Pool

This guide explains how to configure a Rocket Pool node to store its configuration
directory (e.g. `~/.rocketpool`) in an encrypted LUKS file container (not to be confused with Docker containers).

This provides an added layer of security for node operators by keeping all Rocket
Pool configuration assets encrypted.

We describe an unattended unlock scheme, where the LUKS container will unlock
automatically on every boot.

Note that the full decryption key is never stored on the node.
The LUKS container is unlocked by fetching a partial decryption key from an external host.

### Rationale

The LUKS container will be automatically decrypted after every boot.

This approach is reasonable in a threat model where a thief taking the device is unaware of its purpose (staking).
A determined attacker, going after the keys specifically, will be able to subvert both this and the original Aegis key approaches - by simply using a boot disk while taking the care to not power down the node.

With this in mind, the automatic unlock scheme does still provides some security margin:

  * If the (partial) decryption key is on a local server, the node will not be able to decrypt the container unless the local server is also stolen and properly configured on the attacker's network
  * If the (partial) decryption key is on a remote server, we can delete it before the attacker boots up the server on a new location
  * We can deploy creative countermeasures to slow down an adversary even more, and gain us enough time to scrub the remote key from its location

### Setup unattended LUKS container

1. Download the LUKS container creation script:
    ```shell
    curl -LO https://raw.githubusercontent.com/poupas/SecureKey/main/scripts/create-luks-container.sh
    chmod +x create-luks-container.sh
    ```

1. Create a LUKS container
    ```shell
    ./create-luks-container.sh unattended vault 2GiB
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
    sudo chown ${USER} -R -- /var/lib/luks/vault/
    mkdir /var/lib/luks/vault/rocketpool
    sudo cp -a ~/.rocketpool/* /var/lib/luks/vault/rocketpool/
    mv .rocketpool .rocketpool.bak # We will remove this later
    ln -s /var/lib/luks/vault/rocketpool $HOME/.rocketpool
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
    apt-get install secure-delete
    sudo srm -r ${USER}/.rocketpool.bak
    ```
 
## Removing the LUKS container

**WARNING**: here be dragons. Be careful to not remove a LUKS container currently in use by Rocket Pool.

Removing the encrypted container will destroy all data stored inside it. Make sure you have copies of any important data you wish to keep.

```shell
sudo systemctl disable --now mount-vault.service
sudo rm /etc/systemd/system/mount-vault.service
sudo rm -r /var/lib/luks/.containers/vault
```