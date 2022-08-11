#!/bin/sh

LUKS_PATH="/var/lib/luks"
LUKS_CONTAINERS_PATH="${LUKS_PATH}/.containers"
LUKS_MOUNTS_PATH="${LUKS_PATH}"
ENCRYPTED_DATA_FILE="data"
INITIALIZED_MARKER=".init-done"

set -eu

if [ "$(id -u)" != "0" ]; then
    echo "You need to be root to run this script"
    exit 1
fi

mix_pepper_and_key() {
    name="$1"
    key="$2"
    pepper="$(cat ${LUKS_CONTAINERS_PATH}/${name}/pepper)"
    echo "${pepper}${key}" | openssl dgst -sha256 -binary | base32 -w0 | sed 's/=//g' | tr '[:upper:]' '[:lower:]'
}

create_key() {
    dd if=/dev/urandom bs=1 count=35 2>/dev/null | base32 -w0 | tr '[:upper:]' '[:lower:]'
}

check_remote_key() {
    key="$1"
    exec 3>&1 >&2
    echo "Generated remote unlock key: ${key}"
    echo "Please upload the above key to a remote server. Paste the URL in the next prompt"
    while true; do
        read -p "URL> " url
        echo -n "Checking remote key... "
        if ! verify_key_url ${key} ${url}; then
            continue
        fi
        echo -ne "OK\n"
        break
    done
    exec 1>&3 3>&-
    echo "${url}"
}

verify_key_url() {
    check_key="$1"
    url="$2"
    remote_key="$(curl -L -sS ${url})"
    if [ "${remote_key}" = "${check_key}" ]; then
        return 0
    fi
    echo -n "Key on \"${url}\" does not match check key: "
    echo "remote: ${remote_key} != local: ${check_key}"
    return 1
}

create_pepper() {
    data_path="${LUKS_CONTAINERS_PATH}/$1"
    if [ ! -d ${data_path} ]; then
        echo "Error: data path ${data_path} does not exist!"
        return 1
    fi
    dd if=/dev/urandom bs=1 count=35 iflag=fullblock 2>/dev/null | base32 -w0 > ${data_path}/pepper
}

create_data_file() {
    data_path="${LUKS_CONTAINERS_PATH}/$1"
    size=$2
    mkdir -m 0700 -p ${data_path} &&
    fallocate -l ${size} "${data_path}/${ENCRYPTED_DATA_FILE}" &&
    chmod 0600 "${data_path}/${ENCRYPTED_DATA_FILE}"
}

create_container() {
    name="$1"
    key="$2"

    data_path="${LUKS_CONTAINERS_PATH}/${name}"
    mnt_path="${LUKS_MOUNTS_PATH}/${name}"
    format_cmd="cryptsetup -q luksFormat ${data_path}/${ENCRYPTED_DATA_FILE}"
    open_cmd="cryptsetup -q luksOpen ${data_path}/${ENCRYPTED_DATA_FILE} ${name}"

    if [ "${key}" != "" ]; then
        # Automatic unlock
        { echo ${key} | ${format_cmd} --key-file=-; } &&
        { echo ${key} | ${open_cmd} --key-file=-; } ||
        return 1
    else
        # Manual unlock
        ${format_cmd} --verify-passphrase &&
        ${open_cmd} ||
        return 1
    fi

    mkfs.ext4 /dev/mapper/${name} >/dev/null &&
    mkdir -p ${mnt_path} &&
    chmod 0000 ${mnt_path} &&
    mount /dev/mapper/${name} ${mnt_path} &&
    { /sbin/restorecon -v -R ${mnt_path} >/dev/null 2>&1 || true; } &&
    umount /dev/mapper/${name} &&
    cryptsetup luksClose ${name} 
}

# Yanked from the Rocket Pool installer
get_linux_platform() {
    platform=$(uname -s)
    if [ "$platform" != "Linux" ]; then
        return 1
    fi

    if command -v lsb_release >/dev/null 2>&1; then
        platform=$(lsb_release -si)
    elif [ -f "/etc/centos-release" ]; then
        platform="CentOS"
    elif [ -f "/etc/fedora-release" ]; then
        platform="Fedora"
    elif [ -f "/etc/redhat-relase" ]; then
        platform="RedHat"
    fi

    echo ${platform}
}

check_dependencies() {
    for cmd in cryptsetup fallocate curl; do
        if ! command -v ${cmd} >/dev/null 2>&1; then
            install_dependencies
            return $?
        fi
    done
}

install_dependencies() {
    case $(get_linux_platform) in
        Ubuntu|Debian|Raspbian)
            apt-get update -y >/dev/null 2>&1 &&
            apt-get install -y util-linux cryptsetup curl >/dev/null 2>&1
        ;;
        CentOS|Fedora|RedHat)
            yum update -y >/dev/null 2>&1 &&
            yum install -y util-linux cryptsetup curl >/dev/null 2>&1
        ;;
        *)
            echo "Could not find dependencies. Make sure fallocate, cryptsetup, and curl are installed"
            return 1
        ;;
    esac
}

init_base_paths() {
    mkdir -p -m 0711 ${LUKS_MOUNTS_PATH}
    mkdir -p -m 0700 ${LUKS_CONTAINERS_PATH}
}

deploy_systemd_units() {
    name=$1
    cat << EOF > /etc/systemd/system/mount-${name}.service
[Unit]
Description=Mount dm-crypt/LUKS container
After=network-online.target
Wants=network-online.target
Before=docker.service

[Service]
Type=oneshot
ExecStart=/bin/sh "${LUKS_CONTAINERS_PATH}/${name}/mount.sh"
RemainAfterExit=true
ExecStop=/usr/bin/umount "${LUKS_MOUNTS_PATH}/${name}"
ExecStop=/sbin/cryptsetup -d - -v luksClose ${name}

[Install]
RequiredBy=docker.service
EOF
    systemctl daemon-reload
}

deploy_manual_control_scripts() {
    name="$1"

    # Mount script
    cat << EOF > "${LUKS_CONTAINERS_PATH}/${name}/mount.sh"
#!/bin/sh

set -eu

echo "This LUKS container requires a manual unlock"
echo "Please run ${LUKS_CONTAINERS_PATH}/${name}/unlock.sh to unlock it"
echo "Waiting for container unlock..."

while true; do
    if [ -L /dev/mapper/${name} ]; then
        break
    fi
    sleep 1
done

echo "Container unlocked. Mounting ${LUKS_MOUNTS_PATH}/${name}..."
mount -o noatime /dev/mapper/${name} ${LUKS_MOUNTS_PATH}/${name}
EOF

    # Unlock script
    cat << EOF > "${LUKS_CONTAINERS_PATH}/${name}/unlock.sh" 
#!/bin/sh
set -eu
cryptsetup luksOpen -q ${LUKS_CONTAINERS_PATH}/${name}/${ENCRYPTED_DATA_FILE} ${name}
EOF

    # Set permissions
    chmod 0500 -- ${LUKS_CONTAINERS_PATH}/${name}/*.sh
}

deploy_unattended_control_scripts() {
    name="$1"
    url="$2"

    # Mount script
    cat << EOF > "${LUKS_CONTAINERS_PATH}/${name}/mount.sh"
#!/bin/sh

set -eu

mix_pepper_and_key() {
    name="\$1"
    key="\$2"
    pepper="\$(cat ${LUKS_CONTAINERS_PATH}/${name}/pepper)"
    echo "\${pepper}\${key}" | openssl dgst -sha256 -binary | base32 -w0 | sed 's/=//g' | tr '[:upper:]' '[:lower:]'
}

remote_key=\$(curl -sS -L ${url})
key=\$(mix_pepper_and_key ${name} \${remote_key})

echo \${key} | cryptsetup luksOpen -q --key-file=- ${LUKS_CONTAINERS_PATH}/${name}/${ENCRYPTED_DATA_FILE} ${name}
echo "Container unlocked. Mounting ${LUKS_MOUNTS_PATH}/${name}..."
mount -o noatime /dev/mapper/${name} ${LUKS_MOUNTS_PATH}/${name}
EOF

    # Set permissions
    chmod 0500 -- ${LUKS_CONTAINERS_PATH}/${name}/*.sh
}

set_container_as_initialized() {
    touch "${LUKS_CONTAINERS_PATH}/$1/${INITIALIZED_MARKER}"
}

is_container_initialized() {
    [ -f "${LUKS_CONTAINERS_PATH}/$1/${INITIALIZED_MARKER}" ]
}

umask 0077
ACTION=${1-:}
case "${ACTION}" in
    manual)
        type=$1
        shift
        # Expected arguments: name, size
        if [ $# -ne 2 ]; then
            echo "usage: $0 ${type} NAME SIZE"
            echo "example: $0 ${type} vault 2GB"
            exit 1
        fi
        name=$1
        size=$2

        is_container_initialized ${name} && echo "Error: LUKS container is already initialized" && exit 1
        check_dependencies
        init_base_paths
        create_data_file ${name} ${size}
        create_container ${name} ""
        deploy_systemd_units ${name}
        deploy_manual_control_scripts ${name}
        set_container_as_initialized ${name}
        ;;

    unattended)
        type=$1
        shift
        # Expected arguments: name, size
        if [ $# -ne 2 ]; then
            echo "usage: $0 ${type} NAME SIZE"
            echo "example: $0 ${type} vault 2GB"
            exit 1
        fi
        name=$1
        size=$2

        is_container_initialized ${name} && echo "Error: LUKS container is already initialized" && exit 1
        check_dependencies
        init_base_paths
        key=$(create_key)
        url=$(check_remote_key ${key})
        create_data_file ${name} ${size}
        create_pepper ${name}
        full_key=$(mix_pepper_and_key ${name} ${key})
        create_container ${name} ${full_key}
        deploy_systemd_units ${name}
        deploy_unattended_control_scripts ${name} ${url}

        echo
        echo "Manual unlock keyfile contents: ${full_key}"
        echo "Please save it in a secure location (not on this node)."
        echo
        echo "If the remote key server is unavailable, you can manually unlock the LUKS container with:"
        echo "cryptsetup luksOpen ${LUKS_CONTAINERS_PATH}/${name}/data ${name} --key-file=/path/to/keyfile"
        echo

        set_container_as_initialized ${name}
        ;;

    interactive)
        shift
        echo "Soon (tm)..."
        ;;

    *)
    echo "usage: $0 <manual|unattended|interactive>"
    ;;
esac
