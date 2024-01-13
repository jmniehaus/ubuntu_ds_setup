#!/bin/bash

# Exit on any error
set -e
MESSAGES=""

TMPDIR="/tmp/ds_ubuntu_setup"
mkdir "$TMPDIR"
HOMEDIR="/home/$(logname)" # define this because must be executed using sudo, so $HOME points to root.


function cleanup() {
    [ -d "$TMPDIR" ] && rm -r "$TMPDIR" && echo -e "${MESSAGES[@]}"
}

trap cleanup EXIT


DISTRO=$(lsb_release -a | grep Description | awk '{print $2}')
VERSION=$(lsb_release -a | grep Release | awk '{print $2}' | cut -d. -f1)
CODENAME=$(lsb_release -a | grep Codename | awk '{print $2}')



#------------------------------------------------
# define function to confirm based on a prompt
function confirm() {
    local prompt="$1"
    local no="$2"

    PS3='(1/2)> '

    printf "$prompt" > /dev/tty

    options=("Yes" "No")
    select choice in "${options[@]}"; do
        case "$REPLY" in
            1 ) return ;;
            2 ) echo "$no" ; exit ;;
            *) echo "Invalid input, enter 1 or 2."; continue ;;
        esac
    done
    unset PS3
}

#------------------------------------------------
# get curl dependency

if ! command -v curl &> /dev/null || ! command -v gdebi &> /dev/null; then
    CURL_PROMPT="\ncurl and gdebi-core are a required dependencies for this script. Would you like to install them?\n"
    confirm "$CURL_PROMPT" "Aborted. No dependency: curl."

    apt-get update
    apt-get install curl gdebi-core
fi



#------------------------------------------------

# Get users to specify what packages they want installed
PACKAGE_NAMES=("R" "rstudio" "intel-mkl" "vscode" "miniconda" "rclone" "texlive" "texstudio")

# Display the list of options
for i in "${!PACKAGE_NAMES[@]}"; do
  echo "$((i+1)). ${PACKAGE_NAMES[i]}"
done

printf "Select packages using commas or a range, or both (e.g., 1,2,3-5,8):\n"
read -p "> " SELECTED_PKG_NUMBERS_STR

# Process the input to extract selected options
SELECTED_PKG_NAMES=()

IFS=',' read -ra options <<< "$SELECTED_PKG_NUMBERS_STR"
for option in "${options[@]}"; do
    if [[ $option =~ ^[0-9]+$ ]]; then
        SELECTED_PKG_NAMES+=("${PACKAGE_NAMES[option-1]}")
    elif [[ $option =~ ^[0-9]+-[0-9]+$ ]]; then
        # Range of numbers
        range=($(echo "$option" | tr '-' ' '))
        for ((i = ${range[0]}; i <= ${range[1]}; i++)); do
            SELECTED_PKG_NAMES+=("${PACKAGE_NAMES[i-1]}")
        done
    else
        echo "Invalid input: $option"
        exit 1
    fi
done


# confirm installing correct packages
IFS=", "
PROMPT_PACKAGES="\n\nCONFIRM PACKAGES TO INSTALL:\n${SELECTED_PKG_NAMES[*]}\n\n"
confirm "${PROMPT_PACKAGES}" "Aborted, user indicated incorrect selection."
unset IFS

#------------------------------------------------
# check which selected packages are already installed, confirm if reinstall desired.
TO_INSTALL=()
PS3='(1/2)> '
for pkg in "${SELECTED_PKG_NAMES[@]}"; do
    if [ $pkg == 'vscode' ] ; then pkg='code'; fi

    if command -v "$pkg" &> /dev/null || dpkg -l "$pkg" &> /dev/null || which "$pkg" &> /dev/null || [ -d $HOMEDIR/${pkg} ] ; then
        printf "\n$pkg is already installed. Would you like to update it?\n"
        select choice in "Yes, reinstall" "No, skip"; do
            case "$REPLY" in
                1 ) TO_INSTALL+=("$pkg"); break ;;
                2 ) break ;;
                *) echo "Invalid input, enter 1 or 2."; continue ;;
            esac
        done
    else
        TO_INSTALL+=("$pkg")
    fi
done

echo $TO_INSTALL
unset PS3

if [[ ${#TO_INSTALL[@]} == 0 ]]; then
    echo "Exiting. No valid packages selected."
    exit 0
fi


#------------------------------------------------

apt-get update

#------------------------------------------------




# Install R
if [[ ${TO_INSTALL[@]} =~ "R" ]]; then
    apt-get install -y r-base r-base-dev
fi

# Install intel-mkl
if [[ ${TO_INSTALL[@]} =~ "intel-mkl" ]]; then
    apt-get install -y intel-mkl
fi




# Install Miniconda
if [[ ${TO_INSTALL[@]} =~ "miniconda" ]]; then
    MINICONDA_INSTALLER="Miniconda3-latest-Linux-x86_64.sh"
    wget https://repo.anaconda.com/miniconda/$MINICONDA_INSTALLER -P "$TMPDIR/"
    rm -rf $HOMEDIR/miniconda
    bash "$TMPDIR/$MINICONDA_INSTALLER" -b -p $HOMEDIR/miniconda

    # Add Miniconda to PATH
    if ! cat $HOMEDIR/.bashrc | grep 'export PATH="$HOME/miniconda/bin:$PATH"'; then
        echo 'export PATH="$HOME/miniconda/bin:$PATH"' >> $HOMEDIR/.bashrc
    fi
fi


# Install RStudio
if [[ ${TO_INSTALL[@]} =~ "rstudio" ]]; then
    if [ "$DISTRO" != 'Ubuntu' ] || ([ "$VERSION" -ne 20 ] && [ "$VERSION" -ne 22 ]); then
        MESSAGES+="WARNING: Rstudio debs built for Ubuntu 22.x or 20.x, but your version is: $VERSION. Attempted install using Ubuntu 22.x deb file, but this may not have worked."
        CODENAME='jammy'
    fi
    RSTUDIO_DEB=$(curl -s "https://posit.co/download/rstudio-desktop/" | grep -E "^\s*rstudio.*\.deb" | head -n 1 | tr -d '[:space:]')
    echo $RSTUDIO_DEB
    wget https://download1.rstudio.org/electron/$CODENAME/amd64/$RSTUDIO_DEB -P "$TMPDIR/"
    gdebi -n "$TMPDIR/$RSTUDIO_DEB"
fi


# rclone
if [[ ${TO_INSTALL[@]} =~ "rclone" ]]; then
    RCLONE_INSTALLER="install.sh"
    wget "https://rclone.org/install.sh" -P "$TMPDIR"
    set +e
    bash $TMPDIR/install.sh
    rclone_status=$?
    set -e
    if [ "$rclone_status" -eq 3 ]; then
        MESSAGES+="rclone was already latest version, installation skipped."
    elif [ "$rclone_status" -eq 0 ]; then
        MESSAGES+="Rclone requires configuration. run 'rclone config'"
    else
        exit $rclone_status
    fi
fi


#vscode
if [[ ${TO_INSTALL[@]} =~ "code" ]]; then
    wget -O "$TMPDIR/code-latest.deb" 'https://code.visualstudio.com/sha/download?build=stable&os=linux-deb-x64'
    gdebi -n "$TMPDIR/code-latest.deb"
fi


#Texlive
if [[ ${TO_INSTALL[@]} =~ "texlive" ]]; then
    apt-get install -y texlive-full
fi

MESSAGES+="\n=================================================="
printf '==================================================\n\nInstallation completed successfully.\n\n***Execute:***\n\n\tsource ~/.bashrc \n\nto reflect changes.\n\n'

exit 0
