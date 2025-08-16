#!/usr/bin/env bash
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
    echo "$1" > /tmp/aa
    case "$1" in
        "AlmaLinux")
            case "$2" in
                8.*|9.*)
                    echo "OK"
                    ;;
                *)
                    echo "FAIL"
                    ;;
            esac
            ;;

        "ALT Server")
            case "$2" in
                10*)
                    echo "OK"
                    ;;
                *)
                    echo "FAIL"
                    ;;
            esac
            ;;

        "ALT SPServer")
            case "$2" in
                8.*)
                    echo "OK"
                    ;;
                *)
                    echo "FAIL"
                    ;;
            esac
            ;;
        "ALT SP Server")
            case "$2" in
                10*)
                    echo "OK"
                    ;;
                *)
                    echo "FAIL"
                    ;;
            esac
            ;;

        "ALT Workstation")
            case "$2" in
                10*)
                    echo "OK"
                    ;;
                *)
                    echo "FAIL"
                    ;;
            esac
            ;;

        "Amazon Linux")
            case "$2" in
                "2023")
                    echo "OK"
                    ;;
                *)
                    echo "FAIL"
                    ;;
            esac
            ;;

        "Astra Linux")
            case "$2" in
                1.*)
                    echo "OK"
                    ;;
                *)
                    echo "FAIL"
                    ;;
            esac
            ;;

        "Calculate")
            case "$2" in
                *)
                    echo "OK"
                    ;;
            esac
            ;;

        "CentOS Linux")
            case "$2" in
                "6"|"7"|"8")
                    echo "OK"
                    ;;
                *)
                    echo "FAIL"
                    ;;
            esac
            ;;

        "CentOS Stream")
            case "$2" in
                "8"|"9")
                    echo "OK"
                    ;;
                *)
                    echo "FAIL"
                    ;;
            esac
            ;;

        "Rocky Linux")
            case "$2" in
                "9.5")
                    echo "OK"
                    ;;
                *)
                    echo "FAIL"
                    ;;
            esac
            ;;

        "Debian GNU/Linux")
            case "$2" in
                "8"|"9"|"10"|"11"|"12")
                    echo "OK"
                    ;;
                *)
                    echo "FAIL"
                    ;;
            esac
            ;;

        "Fedora"|"Fedora Linux")
            case "$2" in
                "28"|"29"|"30"|"31"|"32"|"33"|"34"|"35"|"37")
                    echo "OK"
                    ;;
                *)
                    echo "FAIL"
                    ;;
            esac
            ;;

        "FreeBSD")
            case "$2" in
                12.*|13.*|14.*)
                    echo "OK"
                    ;;
                *)
                    echo "FAIL"
                    ;;
            esac
            ;;

        "openSUSE Leap")
            case "$2" in
                "15.1"|"15.2"|"15.3"|"15.4"|"42.3")
                    echo "OK"
                    ;;
                *)
                    echo "FAIL"
                    ;;
            esac
            ;;

        "openScaler")
            case "$2" in
                "22.03")
                    echo "OK"
                    ;;
                *)
                    echo "FAIL"
                    ;;
            esac
            ;;
        "Oracle Linux Server")
            case "$2" in
                9.*)
                    echo "OK"
                    ;;
                *)
                    echo "FAIL"
                    ;;
            esac
            ;;
        "Red Hat Enterprise Linux Server")
            case "$2" in
                "7.8")
                    echo "OK"
                    ;;
                *)
                    echo "FAIL"
                    ;;
            esac
            ;;
        "Red Hat Enterprise Linux")
            case "$2" in
                "8.2")
                    echo "OK"
                    ;;
                *)
                    echo "FAIL"
                    ;;
            esac
            ;;

        "RED OS")
            case "$2" in
                "7.3")
                    echo "OK"
                    ;;
                *)
                    echo "FAIL"
                    ;;
            esac
            ;;

        "ROSA Chrome Server")
            case "$2" in
                2021.*)
                    echo "OK"
                    ;;
                *)
                    echo "FAIL"
                    ;;
            esac
            ;;

        "ROSA Chrome Desktop")
            case "$2" in
                2021.*)
                    echo "OK"
                    ;;
                *)
                    echo "FAIL"
                    ;;
            esac
            ;;

        "SLES")
            case "$2" in
                "15.2")
                    echo "OK"
                    ;;
                *)
                    echo "FAIL"
                    ;;
            esac
            ;;

        "Ubuntu")
            case "$2" in
                "14.04"|"16.04"|"18.04"|"20.04"|"22.04"|"24.04")
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
        "AlmaLinux")
            case "$2" in
                8.*)
                    echo "dnf"
                    ;;
            esac
            ;;

        "ALT Server")
            case "$2" in
                10*)
                    echo "deb"
                    ;;
            esac
            ;;

        "ALT Workstation")
            case "$2" in
                10*)
                    echo "OK"
                    ;;
                *)
                    echo "FAIL"
                    ;;
            esac
            ;;

        "Calculate")
            case "$2" in
                *)
                    echo "OK"
                    ;;
            esac
            ;;

        "Amazon Linux")
            case "$2" in
                "2023")
                    echo "dnf"
                    ;;
            esac
            ;;

        "CentOS Linux")
            case "$2" in
                "6"|"7")
                    echo "rpm"
                    ;;
                "8")
                    echo "dnf"
                    ;;
            esac
            ;;

        "CentOS Stream")
            case "$2" in
                "8"|"9")
                    echo "dnf"
                    ;;
            esac
            ;;

        "Rocky Linux")
            case "$2" in
                "9.5")
                    echo "dnf"
                    ;;
            esac
            ;;

        "Debian GNU/Linux")
            case "$2" in
                "8"|"9"|"10"|"11"|"12")
                    echo "deb"
                    ;;
            esac
            ;;

        "Fedora"|"Fedora Linux")
            case "$2" in
                "28"|"29"|"30"|"31"|"32"|"33"|"34"|"35"|"37")
                    echo "dnf"
                    ;;
            esac
            ;;

        "openSUSE Leap")
            case "$2" in
                "15.1"|"15.2"|"15.3"|"42.3")
                    echo "rpm"
                    ;;
            esac
            ;;


        "openScaler")
            case "$2" in
                "22.03")
                    echo "OK"
                    ;;
                *)
                    echo "FAIL"
                    ;;
            esac
            ;;
        "Oracle Linux Server")
            case "$2" in
                "9.3")
                    echo "OK"
                    ;;
                *)
                    echo "FAIL"
                    ;;
            esac
            ;;
        "Red Hat Enterprise Linux Server")
            case "$2" in
                "7.8")
                    echo "rpm"
                    ;;
            esac
            ;;

        "Red Hat Enterprise Linux")
            case "$2" in
                "8.2")
                    echo "dnf"
                    ;;
            esac
            ;;

        "RED OS")
            case "$2" in
                "7.3")
                    echo "rpm"
                    ;;
            esac
            ;;

        "SLES")
            case "$2" in
                "15.2")
                    echo "rpm"
                    ;;
            esac
            ;;

        "Ubuntu")
            case "$2" in
                "14.04"|"16.04"|"18.04"|"20.04"|"22.04"|"24.04")
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
    OS_TYPE=$(getOS)
    rm -f /etc/machine-id
    rm -f /var/lib/dbus/machine-id
    touch /etc/machine-id
    if [ "$OS_TYPE" != "FreeBSD" ]; then
      ln -s /etc/machine-id /var/lib/dbus/machine-id
    fi
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
    OS_TYPE=$(getOS)
    OS_VERSION=$(getOSVersion)
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
    rm -f /root/original-ks.cfg
    echo "DONE"
}


function cleanSudoers {
    rm -f /etc/sudoers.d/90-cloud-init-users
    echo "DONE"
}


function cleanLogFiles {
    find /var/log -type f -delete
    if [ -z "$JOURNALCTL_EXISTS" ] ; then
        journalctl --rotate 2>/dev/null
        journalctl --vacuum-time=1s 2>/dev/null
    fi
    echo "DONE"
}


function changeSSHRootLoginToDefault {
  OS_TYPE=$(getOS)
  if [ "$OS_TYPE" == "FreeBSD" ]; then
      sed -i.bak "s/#*.PermitRootLogin.*/PermitRootLogin no/" /etc/ssh/sshd_config
      rm -f /etc/ssh/sshd_config.bak
  else
      sed -i 's/.*PermitRootLogin.*/#PermitRootLogin No/g' /etc/ssh/sshd_config
      echo "DONE"
  fi
}

function changeSSHPasswordLoginToNo {
	sed -i '/.*PasswordAuthentication.*/d' /etc/ssh/sshd_config
	echo "PasswordAuthentication no" >> /etc/ssh/sshd_config
	echo "DONE"
}


function cleanRootPassword {
  OS_TYPE=$(getOS)
  if [ "$OS_TYPE" == "FreeBSD" ]; then
    pw lock root
    pw lock toor
  else
    passwd -d root
    passwd -l root
  fi
    echo "DONE"
}


function removeSystemUser {
    OS_TYPE=$(getOS)
    if [ -n "$YCCLEANUP_SYS_USER" ]; then
        if [ "$OS_TYPE" == "FreeBSD" ]; then
          rmuser  -y "$YCCLEANUP_SYS_USER"
          rm -rf /usr/home/"${YCCLEANUP_SYS_USER:?}"
        else
          userdel -f "$YCCLEANUP_SYS_USER"
          rm -rf /home/"${YCCLEANUP_SYS_USER:?}"
        fi
    fi
    echo "DONE"
}


# Functions for image and VM checking


function getStringsNumInVar {
    VAR="$1"
    if [ "$VAR" == "" ]; then
        echo 0
    else
        echo "$VAR" | wc -l | sed -E 's/[[:space:]]+//g'
    fi
}


function getNonLockedUsers {
    SYSDB_DELIMITER=":"
    NOPASSWORD_VALUES=$(printf '!\n!!\n*\n!*\n*!\n*LOCKED**\n*LOCKED*\n')
    PASSWD_FILE=/etc/shadow
    if [ "$OS_TYPE" == "FreeBSD" ]; then
        PASSWD_FILE=/etc/master.passwd
    fi

    for USER in $(cat /etc/passwd | grep -v -e "^#" | getColumn "$SYSDB_DELIMITER" 1); do
        USERPW=$(cat "$PASSWD_FILE" | grep -v -e "^#" | getRowByColumnValue "$SYSDB_DELIMITER" 1 "$USER" | awk -F "$SYSDB_DELIMITER" '{print($2)}')
        if [ "$USERPW" == "" ]; then
            OS_TYPE=$(getOS)
            if [ "$OS_TYPE" == "ALT Server" ] || [ "$OS_TYPE" == "ALT SPServer" ] || [ "$OS_TYPE" == "ALT SP Server" ] || [ "$OS_TYPE" == "ALT Workstation" ]; then
                USERPW=$(cat /etc/tcb/"$USER"/shadow | getRowByColumnValue "$SYSDB_DELIMITER" 1 "$USER" | awk -F "$SYSDB_DELIMITER" '{print($2)}')
            fi
        fi
        if notIn "$USERPW" "$NOPASSWORD_VALUES"; then
            echo "$USER"
        fi
    done
}


function allUsersAreLocked {
    V="$1"
    NON_LOCKED_USERS=$(getNonLockedUsers)
    if [ "$V" == "normal" ]; then
        NON_LOCKED_USERS_SINGLE_STRING=$(echo $NON_LOCKED_USERS)
        DETAILS=" Details: $NON_LOCKED_USERS_SINGLE_STRING"
    fi
    USERS_COUNT=$(getStringsNumInVar "$NON_LOCKED_USERS")
    if [ "$USERS_COUNT" == "0" ]; then
        echo "PASS;"
    else
        echo "FAIL;${DETAILS}"
    fi
}


function getUsersWithNonEmptyBashHistory {
    SYSDB_DELIMITER=":"
    for USER in $(cat /etc/passwd | grep -v -e "^#" | getColumn "$SYSDB_DELIMITER" 1); do
        USERDIR=$(cat /etc/passwd | grep -v -e "^#" | getRowByColumnValue "$SYSDB_DELIMITER" 1 "$USER" | awk -F "$SYSDB_DELIMITER" '{print($6)}')
        if [ -f "${USERDIR}/.bash_history" ]; then
            if [ -s "${USERDIR}/.bash_history" ]; then
                echo "$USER"
            fi
        fi
    done
}


function allUsersHaveEmptyBashHistory {
    V="$1"
    NON_EMPTYHIST_USERS=$(getUsersWithNonEmptyBashHistory)
    if [ "$V" == "normal" ]; then
        NON_EMPTYHIST_USERS_SINGLE_STRING=$(echo $NON_EMPTYHIST_USERS)
        DETAILS=" Details: $NON_EMPTYHIST_USERS_SINGLE_STRING"
    fi
    USERS_COUNT=$(getStringsNumInVar "$NON_EMPTYHIST_USERS")
    if [ "$USERS_COUNT" == "0" ]; then
        echo "PASS;"
    else
        echo "FAIL;${DETAILS}"
    fi
}


function getUsersWithAuthKeys {
    SYSDB_DELIMITER=":"
    for USER in $(cat /etc/passwd | grep -v -e "^#" | getColumn "$SYSDB_DELIMITER" 1); do
        USERDIR=$(cat /etc/passwd | grep -v -e "^#" | getRowByColumnValue "$SYSDB_DELIMITER" 1 "$USER" | awk -F "$SYSDB_DELIMITER" '{print($6)}')
        if [ -f "${USERDIR}/.ssh/authorized_keys" ]; then
            if [ -s "${USERDIR}/.ssh/authorized_keys" ]; then
                echo "$USER"
            fi
        fi
    done
}


function onlyOneNonRootUserHasAuthKeys {
    V="$1"
    IGNORE_USERS='^root$\|^operator$'
    if [ "$OS_TYPE" == "FreeBSD" ]; then
        # all they point to `root` home dir
        IGNORE_USERS='^root$\|^operator$\|^toor$\|^daemon$\|^admin$'
    fi
    AUTHKEY_USERS=$(getUsersWithAuthKeys | grep -v $IGNORE_USERS)
    if [ "$V" == "normal" ]; then
        AUTHKEY_USERS_SINGLE_STRING=$(echo $AUTHKEY_USERS)
        DETAILS=" Details: $AUTHKEY_USERS_SINGLE_STRING"
    fi
    USERS_COUNT=$(getStringsNumInVar "$AUTHKEY_USERS")
    if [ "$USERS_COUNT" == "1" ]; then
        echo "PASS;"
    else
        echo "FAIL;${DETAILS}"
    fi
}


function noOneUserHasAuthKeys {
    USERS_COUNT=$(getUsersWithAuthKeys | wc -l)
    if [ "$USERS_COUNT" == "0" ]; then
        echo "PASS;"
    else
        echo FAIL;
    fi
}


function getUsersWithMoreThanOneAuthKeys {
    SYSDB_DELIMITER=":"
    for USER in $(cat /etc/passwd | grep -v -e "^#" | getColumn "$SYSDB_DELIMITER" 1); do
        USERDIR=$(cat /etc/passwd | grep -v -e "^#" | getRowByColumnValue "$SYSDB_DELIMITER" 1 "$USER" | awk -F "$SYSDB_DELIMITER" '{print($6)}')
        if [ -f "${USERDIR}/.ssh/authorized_keys" ]; then
            if [ -s "${USERDIR}/.ssh/authorized_keys" ]; then
                KEYS_COUNT=$(cat "${USERDIR}/.ssh/authorized_keys" | grep -v -e "^#" | sort | uniq | wc -l)
                if [ "$KEYS_COUNT" -gt "1" ]; then
                    echo "$USER"
                fi
            fi
        fi
    done
}


function noOneUserHaveMoreThanOneAuthKeys {
    V="$1"
    MORE1AUTHKEY_USERS=$(getUsersWithMoreThanOneAuthKeys)
    if [ "$V" == "normal" ]; then
        MORE1AUTHKEY_USERS_SINGLE_STRING=$(echo $MORE1AUTHKEY_USERS)
        DETAILS=" Details: $MORE1AUTHKEY_USERS_SINGLE_STRING"
    fi
    USERS_COUNT=$(getStringsNumInVar "$MORE1AUTHKEY_USERS")
    if [ "$USERS_COUNT" == "0" ]; then
        echo "PASS;"
    else
        echo "FAIL;${DETAILS}"
    fi
}

function checkSshKey {
  file=$1
  if ssh-keygen -y -e -f "$file" > /dev/null 2>&1; then
    echo "$file is a private SSH key."
  elif ssh-keygen -l -f "$file" > /dev/null 2>&1; then
    echo "$file is a public SSH key."
  else
    echo "$file is not a valid SSH key."
  fi
}

function checkAllFilesInSshDirectory {
  USERDIR=$1
  directory="$USERDIR/.ssh"
  for file in $(ls -a "$directory" | grep -v '^\.$\|^\.\.$\|^authorized_keys$'); do
    result=$(checkSshKey "$directory/$file")
    if [[ $result == *"is a private SSH key"* ]] || [[ $result == *"is a public SSH key"* ]]; then
      echo "$USERDIR"
    fi
  done
}

function getUsersWithKeyPairs {
    SYSDB_DELIMITER=":"
    for USER in $(cat /etc/passwd | grep -v -e "^#" | getColumn "$SYSDB_DELIMITER" 1); do
        USERDIR=$(cat /etc/passwd | grep -v -e "^#" | getRowByColumnValue "$SYSDB_DELIMITER" 1 "$USER" | awk -F "$SYSDB_DELIMITER" '{print($6)}')
        if [ -d "${USERDIR}/.ssh/" ]; then
            checkAllFilesInSshDirectory "$USERDIR"
        fi
    done
}


function noOneUserHasKeyPairs {
    V="$1"
    KEYPAIR_USERS=$(getUsersWithKeyPairs)
    if [ "$V" == "normal" ]; then
        KEYPAIR_USERS_SINGLE_STRING=$(echo $KEYPAIR_USERS)
        DETAILS=" Details: $KEYPAIR_USERS_SINGLE_STRING"
    fi
    USERS_COUNT=$(getStringsNumInVar "$KEYPAIR_USERS")
    if [ "$USERS_COUNT" == "0" ]; then
        echo "PASS;"
    else
        echo "FAIL;${DETAILS}"
    fi
}


function noPasswordAuthSSH {
    V="$1"
    CONF_VAULE=$(sshd -T 2>/dev/null | sed -n 's/^passwordauthentication \(.*\)/\1/p')
    if [ "$V" == "normal" ]; then
        DETAILS=" Details: passwordauthentication ${CONF_VAULE}"
    fi
    if [ "$CONF_VAULE" == "no" ]; then
        echo "PASS;"
    else
        echo "FAIL;${DETAILS}"
    fi
}


# Summary functions

function summarize {
    INPUT=$(cat)
    echo "$INPUT"
    FAILSNUM=$(echo -n "$INPUT" | awk '/FAIL;/' | wc -l)
    if [ "$FAILSNUM" -gt 0 ]; then
        return 1
    fi
    return 0
}

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
    echo -n "changing ssh PasswordAuthentication parameter to 'no'"
    changeSSHPasswordLoginToNo
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
    CHECK_VM_SPECS="$1"
    VERBOSITY="$2"
    CHECK_VM_SPECS_NEWLINES=$(echo $CHECK_VM_SPECS | tr -s ',' '\n')
    if notIn "users-locked-nocheck" "$CHECK_VM_SPECS_NEWLINES"; then
        echo -n "Checking that all users are locked (password or empty password authentication is not allowed)... "
        allUsersAreLocked "$VERBOSITY"
    fi
    if notIn "empty-history-nocheck" "$CHECK_VM_SPECS_NEWLINES"; then
        echo -n "Checking that all users have empty bash history... "
        allUsersHaveEmptyBashHistory "$VERBOSITY"
    fi
    if notIn "one-auth-user-nocheck" "$CHECK_VM_SPECS_NEWLINES"; then
        echo -n "Checking that only one non-root user has non-empty authorized_keys... "
        onlyOneNonRootUserHasAuthKeys "$VERBOSITY"
    fi
    if notIn "one-auth-key-nocheck" "$CHECK_VM_SPECS_NEWLINES"; then
        echo -n "Checking that no one user has more than one record in authorized_keys... "
        noOneUserHaveMoreThanOneAuthKeys "$VERBOSITY"
    fi
    if notIn "no-private-keys-nocheck" "$CHECK_VM_SPECS_NEWLINES"; then
        echo -n "Checking that no one user has key pairs in .ssh directory... "
        noOneUserHasKeyPairs "$VERBOSITY"
    fi
    if notIn "no-passwords-nocheck" "$CHECK_VM_SPECS_NEWLINES"; then
        echo -n "Checking for SSH password authentication is disabled... "
        noPasswordAuthSSH "$VERBOSITY"
    fi
}


# Main

USAGE="Usage: $(basename "$0") -h | -c | -d | -t [ -s SPECS ]
Script for checking and cleaning up a virtual machine image before publication in Yandex Cloud.
This script must be run as superuser. Be careful!

Options (order matters!):
  -h\thelp
  -v\tverbose mode (supported modes: normal)
  -s\tcomma-separated no-whitespaced list of specs for cleanup/check process
  -c\tclean up the image
  -d\tcheck the image just after preparing procedure, \"dry run mode\" of clean up process
  -t\tperform cleanness tests on running VM created from image
  -o\trunning distribution overview and check whether this distribution is supported or not

Results of running tests are printed to the stdout.
In \"-d\" and \"-t\" modes exit code equals to 1 if at least one test fails, 0 otherwise.

Environment variables can be set:
  YCCLEANUP_SYS_USER\tthe username used to perform image preparing tasks"

if [ "$#" -lt "1" ]; then
    echo -e "$USAGE" >&2
    exit 1
fi

while getopts ':hv::s::tcdo' OPTION; do
    case "$OPTION" in
        h)
            echo -e "$USAGE"
            exit
            ;;
        v)
            VERBOSE_MODE="${OPTARG}"
            ;;
        s)
            SPECS="${OPTARG}"
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
                checkImage | summarize
                exit "$?"
            fi
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
                checkVM "$SPECS" "$VERBOSE_MODE" | summarize
                exit "$?"
            fi
            ;;
        o)
            echo "OS & distribution summary"
            OS_TYPE=$(getOS)
            echo "  OS: ${OS_TYPE}"
            OS_VERSION=$(getOSVersion)
            echo "  OS version: ${OS_VERSION}"
            PRECHECK_RESULT=$(preCheck "$OS_TYPE" "$OS_VERSION")
            if [ "$PRECHECK_RESULT" == FAIL ]; then
                echo "  Unsupported OS/distribution; can't determine package manager type"
            else
                PM_TYPE=$(definePMSType "$OS_TYPE" "$OS_VERSION")
                echo "  Package manager type: $PM_TYPE"
            fi
            ;;
        \?)
            echo $(basename "$0")": illegal option -- $OPTARG"
            echo -e "$USAGE" >&2
            exit 1
            ;;
    esac
done
