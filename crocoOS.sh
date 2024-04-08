set -a
SCRIPT_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd)"
SCRIPTS_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd)"/scripts
CONFIGS_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd)"/conf
set +a
echo -ne "
------------------------------------------------------------------------
  ██████╗ ██████╗   ████████   ██████╗  ████████
 ██╔════╝ ██╔══██╗ ██║     ██ ██╔════╝ ██║     ██
 ██║      ██████╔╝ ██║     ██ ██║      ██║     ██
 ██║      ██╔══██╗ ██║     ██ ██║      ██║     ██
 ╚██████╗ ██║  ██║  ████████  ╚██████╗  ████████
  ╚═════╝ ╚═╝  ╚═╝  ╚══════╝   ╚═════╝  ╚══════╝
  ------------------------------------------------------------------------
  "
    ( bash $SCRIPTS_DIR/startup.sh)|& tee strtup.log
      source $CONFIGS_DIR/setup.conf
    ( bash $SCRIPTS_DIR/preinstall.sh)|& tee preinstall.log
    ( arch-chroot /mnt $HOME/CrocoOS/scripts/setup.sh)|& tee setup.log
    if [[ ! $DESKTOM_ENV == server ]]; then
        (arch-chroot /mnt /usr/bin/runuser -u $USERNAME -- /home/$USERNAME/CrocoOS/scripts/user.sh ) |& tee user.lot
    fi
    ( arch-chroot /mnt $HOME/CrocoOS/scripts/post-setup.sh )|& tee post-setup.log
    cp -v *.log /mnt/home/$USERNAME

echo -ne "
------------------------------------------------------------------------
  ██████╗ ██████╗   ████████   ██████╗  ████████
 ██╔════╝ ██╔══██╗ ██║     ██ ██╔════╝ ██║     ██
 ██║      ██████╔╝ ██║     ██ ██║      ██║     ██
 ██║      ██╔══██╗ ██║     ██ ██║      ██║     ██
 ╚██████╗ ██║  ██║  ████████  ╚██████╗  ████████
  ╚═════╝ ╚═╝  ╚═╝  ╚══════╝   ╚═════╝  ╚══════╝
  ------------------------------------------------------------------------
  "