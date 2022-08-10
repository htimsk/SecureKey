# Instructions for using dm-crypt/LUKS with Rocket Pool

This guide explains how to configure a Rocket Pool node to store its configuration
directory (e.g. `~/.rocketpool`) in an encrypted LUKS file container (not to be confused with Docker containers).

This provides an added layer of security for node operators by keeping all Rocket
Pool configuration assets encrypted.

We describe a manual unlock scheme, where the node operator must log 
in into the node and enter the decryption key on every boot.

### Setup encrypted LUKS container

1. Download the LUKS container creation script:
  ```shell
   curl -LO https://raw.githubusercontent.com/poupas/SecureKey/main/scripts/create-luks-container.sh
   chmod +x create-luks-container.sh
   ```

1. Create a LUKS container
  ```shell
  ./create-luks-container.sh manual vault 2GiB
  ```

1. Unlock the LUKS container

**Note**:
  * You will need to run this step every time the node reboots
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
  srm -rfll ${USER}/.rocketpool.bak
  ```
