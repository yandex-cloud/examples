#!/bin/bash

# Common functions

function getOS {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS="$NAME"
    elif type lsb_release >/dev/null 2>&1; then
        OS=$(lsb_release -si)
    elif [ -f /etc/lsb-release ]; then
        . /etc/lsb-release
        OS="$DISTRIB_ID"
    elif [ -f /etc/debian_version ]; then
        OS=Debian
    elif [ -f /etc/redhat-release ]; then
        d=$( cat /etc/redhat-release | cut -d" " -f1 | cut -d "." -f1)
        if [[ "$d" == "CentOS" ]]; then
            OS="CentOS Linux"
        fi
    else
        OS=$(uname -s)
    fi
    echo "$OS"
}


function getOSVersion {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        VER="$VERSION_ID"
    elif type lsb_release >/dev/null 2>&1; then
        VER=$(lsb_release -sr)
    elif [ -f /etc/lsb-release ]; then
        . /etc/lsb-release
        VER="$DISTRIB_RELEASE"
    elif [ -f /etc/debian_version ]; then
        VER=$(cat /etc/debian_version)
    elif [ -f /etc/redhat-release ]; then
        VER=$( cat /etc/redhat-release | cut -d" " -f3 | cut -d "." -f1)
    else
        VER=$(uname -r)
    fi
    echo "$VER"
}


function preCheck {
    case "$1" in
        "CentOS Linux")
            case "$2" in
                "7"|"8")
                    echo "OK"
                    ;;
                *)
                    echo "FAIL"
                    ;;
            esac
            ;;
        "Ubuntu")
            case "$2" in
                "16.04"|"18.04"|"20.04")
                    echo "OK"
                    ;;
                *)
                    echo "FAIL"
                    ;;
            esac
            ;;
        "Debian GNU/Linux")
            case "$2" in
                "10")
                    echo "OK"
                    ;;
                *)
                    echo "FAIL"
                    ;;
            esac
            ;;
        *)
            echo "FAIL"
            ;;
    esac
}


function definePMSType {
    case "$1" in
        "CentOS Linux")
            case "$2" in
                "7")
                    echo "rpm"
                    ;;
                "8")
                    echo "dnf"
                    ;;
            esac
            ;;
        "Ubuntu")
            case "$2" in
                "16.04"|"18.04"|"20.04")
                    echo "deb"
                    ;;
            esac
            ;;
        "Debian GNU/Linux")
            case "$2" in
                "10")
                    echo "deb"
                    ;;
            esac
            ;;
    esac
}


function getColumn {
    DELIMITER="$1"
    FIELD="$2"
    awk -v FIELD="$FIELD" -F "$DELIMITER" '{print($FIELD)}'
}


function getRowByColumnValue {
    DELIMITER="$1"
    FIELD="$2"
    VALUE="$3"
    awk -v FIELD="$FIELD" -v VALUE="$VALUE" -F "$DELIMITER" '$FIELD == VALUE'
}


function notIn {
    TESTING_VALUE="$1"
    LIST="$2" # Newline-separated
    echo "$LIST" | while read V; do
        if [ "$TESTING_VALUE" == "$V" ]; then
            exit 1
        fi
    done
    return $?
}


# Functions for image cleaning up

function cleanSSHKeyPairs {
    rm -f /etc/ssh/*_key*
    echo "DONE"
}


function cleanMachineID {
    rm -f /etc/machine-id
    rm -f /var/lib/dbus/machine-id
    touch /etc/machine-id
    ln -s /etc/machine-id /var/lib/dbus/machine-id
    echo "DONE"
}


function cleanDHCPLeases {
    if [ -d "/var/lib/dhcp" ]; then
        rm -rf /var/lib/dhcp/*
    fi
    echo "DONE"
}


function cleanTmp {
    rm -rf /tmp/*
    echo "DONE"
}


function cleanPackageCache {
    OS_TYPE="$1"
    OS_VERSION="$2"
    PMS_TYPE=$(definePMSType $OS_TYPE $OS_VERSION)
    case "$PMS_TYPE" in
        "deb")
            apt-get -y autoremove --purge
            apt-get -y clean
            apt-get -y autoclean
            ;;
        "rpm")
            yum clean all -y
            ;;
        "dnf")
            dnf -y autoremove
            ;;
    esac
    echo "DONE"
}


function cleanBashHistory {
    unset HISTFILE
    rm -f /root/.bash_history
    rm -rf /root/.ssh/*
    echo "DONE"
}


function cleanSudoers {
    rm -f /etc/sudoers.d/90-cloud-init-users
    echo "DONE"
}


function cleanLogFiles {
    find /var/log -type f -delete
    if [ -z "$JOURNALCTL_EXISTS" ] ; then
        journalctl --rotate
        journalctl --vacuum-time=1s
    fi
    echo "DONE"
}


function changeSSHRootLoginToDefault {
    sed -i 's/.*PermitRootLogin.*/#PermitRootLogin No/g' /etc/ssh/sshd_config
    echo "DONE"
}


function cleanRootPassword {
    passwd -d root
    passwd -l root
    echo "DONE"
}


function removeSystemUser {
    if [ ! -z "$YCCLEANUP_SYS_USER" ]; then
        userdel -f "$YCCLEANUP_SYS_USER"
        rm -rf /home/"$YCCLEANUP_SYS_USER"
    fi
    echo "DONE"
}


# Functions for image and VM checking

function getNonLockedUsers {
    SYSDB_DELIMITER=":"
    NOPASSWORD_VALUES=$(printf '!\n!!\n*\n')
    for USER in $(cat /etc/passwd | getColumn "$SYSDB_DELIMITER" 1); do
        USERPW=$(cat /etc/shadow | getRowByColumnValue "$SYSDB_DELIMITER" 1 "$USER" | awk -F "$SYSDB_DELIMITER" '{print($2)}')
        if notIn "$USERPW" "$NOPASSWORD_VALUES"; then
            echo "$USER"
        fi
    done
}


function allUsersAreLocked {
    USERS_COUNT=$(getNonLockedUsers | wc -l)
    if [ "$USERS_COUNT" -eq "0" ]; then
        echo PASS
    else
        echo FAIL
    fi
}


function getUsersWithNonEmptyBashHistory {
    SYSDB_DELIMITER=":"
    for USER in $(cat /etc/passwd | getColumn "$SYSDB_DELIMITER" 1); do
        USERDIR=$(cat /etc/passwd | getRowByColumnValue "$SYSDB_DELIMITER" 1 "$USER" | awk -F "$SYSDB_DELIMITER" '{print($6)}')
        if [ -f "${USERDIR}/.bash_history" ]; then
            if [ -s "${USERDIR}/.bash_history" ]; then
                echo "$USER"
            fi
        fi
    done
}


function allUsersHaveEmptyBashHistory {
    USERS_COUNT=$(getUsersWithNonEmptyBashHistory | wc -l)
    if [ "$USERS_COUNT" -eq "0" ]; then
        echo PASS
    else
        echo FAIL
    fi
}


function getUsersWithAuthKeys {
    SYSDB_DELIMITER=":"
    for USER in $(cat /etc/passwd | getColumn "$SYSDB_DELIMITER" 1); do
        USERDIR=$(cat /etc/passwd | getRowByColumnValue "$SYSDB_DELIMITER" 1 "$USER" | awk -F "$SYSDB_DELIMITER" '{print($6)}')
        if [ -f "${USERDIR}/.ssh/authorized_keys" ]; then
            if [ -s "${USERDIR}/.ssh/authorized_keys" ]; then
                echo "$USER"
            fi
        fi
    done
}


function onlyOneNonRootUserHasAuthKeys {
    USERS_COUNT=$(getUsersWithAuthKeys | grep -v '^root$\|^operator$' | wc -l)
    if [ "$USERS_COUNT" -eq "1" ]; then
        echo PASS
    else
        echo FAIL
    fi
}


function noOneUserHasAuthKeys {
    USERS_COUNT=$(getUsersWithAuthKeys | wc -l)
    if [ "$USERS_COUNT" -eq "0" ]; then
        echo PASS
    else
        echo FAIL
    fi
}


function getUsersWithMoreThanOneAuthKeys {
    SYSDB_DELIMITER=":"
    for USER in $(cat /etc/passwd | getColumn "$SYSDB_DELIMITER" 1); do
        USERDIR=$(cat /etc/passwd | getRowByColumnValue "$SYSDB_DELIMITER" 1 "$USER" | awk -F "$SYSDB_DELIMITER" '{print($6)}')
        if [ -f "${USERDIR}/.ssh/authorized_keys" ]; then
            if [ -s "${USERDIR}/.ssh/authorized_keys" ]; then
                KEYS_COUNT=$(cat "${USERDIR}/.ssh/authorized_keys" | wc -l)
                if [ "$KEYS_COUNT" -gt "1" ]; then
                    echo "$USER"
                fi
            fi
        fi
    done
}


function noOneUserHaveMoreThanOneAuthKeys {
    USERS_COUNT=$(getUsersWithMoreThanOneAuthKeys | wc -l)
    if [ "$USERS_COUNT" -eq "0" ]; then
        echo PASS
    else
        echo FAIL
    fi
}


function getUsersWithKeyPairs {
    SYSDB_DELIMITER=":"
    for USER in $(cat /etc/passwd | getColumn "$SYSDB_DELIMITER" 1); do
        USERDIR=$(cat /etc/passwd | getRowByColumnValue "$SYSDB_DELIMITER" 1 "$USER" | awk -F "$SYSDB_DELIMITER" '{print($6)}')
        if [ -d "${USERDIR}/.ssh/" ]; then
            FILES_COUNT=$(ls -a "${USERDIR}/.ssh/" | grep -v '^\.$\|^\.\.$\|^authorized_keys$' | wc -l)
            if [ "$FILES_COUNT" -gt "0" ]; then
                echo "$USER"
            fi
        fi
    done
}


function noOneUserHasKeyPairs {
    USERS_COUNT=$(getUsersWithKeyPairs | wc -l)
    if [ "$USERS_COUNT" -eq "0" ]; then
        echo PASS
    else
        echo FAIL
    fi
}


function noPasswordAuthSSH {
    CONF_VAULE=$(sshd -T 2>/dev/null | sed -n 's/^passwordauthentication \(.*\)/\1/p')
    if [ "$CONF_VAULE" == "no" ]; then
        echo PASS
    else
        echo FAIL
    fi
}


# Summary functions

function cleanupImage {
    echo -n "Starting to clean up SSH key pairs... "
    cleanSSHKeyPairs
    echo -n "Starting to clean up machine ID... "
    cleanMachineID
    echo -n "Starting to clean up DHCP leases... "
    cleanDHCPLeases
    echo -n "Starting to clean up /tmp... "
    cleanTmp
    echo -n "Starting to clean up package cache... "
    cleanPackageCache
    echo -n "Starting to clean up bash history... "
    cleanBashHistory
    echo -n "Starting to clean up sudoers config... "
    cleanSudoers
    echo -n "Starting to clean up log files... "
    cleanLogFiles
    echo -n "Changing ssh PermitRootLogin parameter to the default value... "
    changeSSHRootLoginToDefault
    echo -n "Starting to clean up root password... "
    cleanRootPassword
    echo -n "Removing system user... "
    removeSystemUser
}


function checkImage {
    echo -n "Checking that all users are locked (password or empty password authentication is not allowed)... "
    allUsersAreLocked
    echo -n "Checking that all users have empty bash history... "
    allUsersHaveEmptyBashHistory
    echo -n "Checking that no one user has authorized_keys... "
    noOneUserHasAuthKeys
    echo -n "Checking that no one user has key pairs in .ssh directory... "
    noOneUserHasKeyPairs
    echo -n "Checking for SSH password authentication is disabled... "
    noPasswordAuthSSH
}


function checkVM {
    echo -n "Checking that all users are locked (password or empty password authentication is not allowed)... "
    allUsersAreLocked
    echo -n "Checking that all users have empty bash history... "
    allUsersHaveEmptyBashHistory
    echo -n "Checking that only one non-root user has non-empty authorized_keys... "
    onlyOneNonRootUserHasAuthKeys
    echo -n "Checking that no one user has more than one record in authorized_keys... "
    noOneUserHaveMoreThanOneAuthKeys
    echo -n "Checking that no one user has key pairs in .ssh directory... "
    noOneUserHasKeyPairs
    echo -n "Checking for SSH password authentication is disabled... "
    noPasswordAuthSSH
}


# Main

USAGE="Usage: $(basename "$0") -h | -c | -d | -t
Script for checking and cleaning up a virtual machine image before publication in Yandex Cloud.
This script must be run as superuser. Be careful!

Options:
  -h\thelp
  -c\tclean up the image
  -d\tcheck the image just after preparing procedure, \"dry run mode\" of clean up process
  -t\tperform cleannes tests on running VM created from image
  
Environment variables can be set:
  YCCLEANUP_SYS_USER\tthe username used to perform image preparing tasks"

if [ "$#" -ne "1" ]; then
    echo -e "$USAGE" >&2
    exit 1
fi

while getopts ':htcd' OPTION; do
    case "$OPTION" in
        h) 
            echo -e "$USAGE"
            exit
            ;;
        c)
            echo "# Cleaning up the image"
            OS_TYPE=$(getOS)
            OS_VERSION=$(getOSVersion)
            PRE_CHECK_RESULT=$(preCheck "$OS_TYPE" "$OS_VERSION")
            if [ "$PRE_CHECK_RESULT" == "FAIL" ]; then
                echo "Unsupported OS/distribution: $OS_TYPE/$OS_VERSION"
                exit 1
            else
                cleanupImage
            fi
            exit
            ;;
        d)
            echo "# Checking the image for cleannes"
            OS_TYPE=$(getOS)
            OS_VERSION=$(getOSVersion)
            PRE_CHECK_RESULT=$(preCheck "$OS_TYPE" "$OS_VERSION")
            if [ "$PRE_CHECK_RESULT" == "FAIL" ]; then
                echo "Unsupported OS/distribution: $OS_TYPE/$OS_VERSION"
                exit 1
            else
                checkImage
            fi
            exit
            ;;
        t)
            echo "# Checking the VM for cleannes"
            OS_TYPE=$(getOS)
            OS_VERSION=$(getOSVersion)
            PRE_CHECK_RESULT=$(preCheck "$OS_TYPE" "$OS_VERSION")
            if [ "$PRE_CHECK_RESULT" == "FAIL" ]; then
                echo "Unsupported OS/distribution: $OS_TYPE/$OS_VERSION"
                exit 1
            else
                checkVM
            fi
            exit
            ;;
        \?)
            echo $(basename "$0")": illegal option -- $OPTARG"
            echo -e "$USAGE" >&2
            exit 1
            ;;
    esac
done
