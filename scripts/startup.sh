CONFIG_FILE=$CONFIGS_DIR/setup.conf
if [ ! -f $CONFIG_FILE ]; then # check if file exists
    touch -f $CONFIG_FILE # create file if not exists
fi

set_option() {
    if grep -Eq "^${1}.*" $CONFIG_FILE; then # check if option exists
        sed -i -e "/^${1}.*/d" $CONFIG_FILE # delete option if exists
    fi
    echo "${1}=${2}" >>$CONFIG_FILE # add option
}

set_password() {
    read -rs -p "Podaj haslo: " PASSWORD1
    echo -ne "\n"
    read -rs -p "podaj ponownie haslo: " PASSWORD2
    echo -ne "\n"
    if [[ "$PASSWORD1" == "$PASSWORD2" ]]; then
        set_option "$1" "$PASSWORD1"
    else
        echo -ne "ERROR! hasla nie sa identyczne. \n"
        set_password
    fi
}

root_check() {
    if [[ "$(id -u)" != "0" ]]; then
        echo -ne "ERROR! ten skrypt musi byc uruchomionyz uprawnieniami 'root'!\n"
        exit 0
    fi
}

docker_check() {
    if awk -F/ '$2 == "docker"' /proc/self/cgroup | read -r; then
        echo -ne "ERROR! Docker container nie jest wspierany(w tym momencie)\n"
        exit 0
    elif [[ -f /.dockerenv ]]; then
        echo -ne "ERROR! Docker container nie jest wspierany(w tym momencie)\n"
        exit 0
    fi
}
arch_check() {
    if [[ ! -e /etc/arch-release ]]; then
        echo -ne "ERROR! ten skrypt musi byc uruchomiony w arch linux!\n"
        exit 0
    fi
}
pacman_check() {
    if [[ -f /var/lib/pacman/db.lck ]]; then
        echo "ERROR! Pacman jest zablokowany."
        echo -ne "jeżeli to nie dziala usun /var/lib/pacman/db.lck.\n"
        exit 0
    fi
}
checks() {
    root_check
    arch_check
    pacman_check
    docker_check
}
select_option() {

    # little helpers for terminal print control and key input
    ESC=$( printf "\033")
    cursor_blink_on()  { printf "$ESC[?25h"; }
    cursor_blink_off() { printf "$ESC[?25l"; }
    cursor_to()        { printf "$ESC[$1;${2:-1}H"; }
    print_option()     { printf "$2   $1 "; }
    print_selected()   { printf "$2  $ESC[7m $1 $ESC[27m"; }
    get_cursor_row()   { IFS=';' read -sdR -p $'\E[6n' ROW COL; echo ${ROW#*[}; }
    get_cursor_col()   { IFS=';' read -sdR -p $'\E[6n' ROW COL; echo ${COL#*[}; }
    key_input()         {
                        local key
                        IFS= read -rsn1 key 2>/dev/null >&2
                        if [[ $key = ""      ]]; then echo enter; fi;
                        if [[ $key = $'\x20' ]]; then echo space; fi;
                        if [[ $key = "k" ]]; then echo up; fi;
                        if [[ $key = "j" ]]; then echo down; fi;
                        if [[ $key = "h" ]]; then echo left; fi;
                        if [[ $key = "l" ]]; then echo right; fi;
                        if [[ $key = "a" ]]; then echo all; fi;
                        if [[ $key = "n" ]]; then echo none; fi;
                        if [[ $key = $'\x1b' ]]; then
                            read -rsn2 key
                            if [[ $key = [A || $key = k ]]; then echo up;    fi;
                            if [[ $key = [B || $key = j ]]; then echo down;  fi;
                            if [[ $key = [C || $key = l ]]; then echo right;  fi;
                            if [[ $key = [D || $key = h ]]; then echo left;  fi;
                        fi 
    }
    print_options_multicol() {
        # print options by overwriting the last lines
        local curr_col=$1
        local curr_row=$2
        local curr_idx=0

        local idx=0
        local row=0
        local col=0
        
        curr_idx=$(( $curr_col + $curr_row * $colmax ))
        
        for option in "${options[@]}"; do

            row=$(( $idx/$colmax ))
            col=$(( $idx - $row * $colmax ))

            cursor_to $(( $startrow + $row + 1)) $(( $offset * $col + 1))
            if [ $idx -eq $curr_idx ]; then
                print_selected "$option"
            else
                print_option "$option"
            fi
            ((idx++))
        done
    }
    for opt; do printf "\n"; done

    # determine current screen position for overwriting the options
    local return_value=$1
    local lastrow=`get_cursor_row`
    local lastcol=`get_cursor_col`
    local startrow=$(($lastrow - $#))
    local startcol=1
    local lines=$( tput lines )
    local cols=$( tput cols ) 
    local colmax=$2
    local offset=$(( $cols / $colmax ))

    local size=$4
    shift 4

    # ensure cursor and input echoing back on upon a ctrl+c during read -s
    trap "cursor_blink_on; stty echo; printf '\n'; exit" 2
    cursor_blink_off

    local active_row=0
    local active_col=0
    while true; do
        print_options_multicol $active_col $active_row 
        # user key control
        case `key_input` in
            enter)  break;;
            up)     ((active_row--));
                    if [ $active_row -lt 0 ]; then active_row=0; fi;;
            down)   ((active_row++));
                    if [ $active_row -ge $(( ${#options[@]} / $colmax ))  ]; then active_row=$(( ${#options[@]} / $colmax )); fi;;
            left)     ((active_col=$active_col - 1));
                    if [ $active_col -lt 0 ]; then active_col=0; fi;;
            right)     ((active_col=$active_col + 1));
                    if [ $active_col -ge $colmax ]; then active_col=$(( $colmax - 1 )) ; fi;;
        esac
    done

    # cursor position back to normal
    cursor_to $lastrow
    printf "\n"
    cursor_blink_on

    return $(( $active_col + $active_row * $colmax ))

logo () {
# This will be shown on every set as user is progressing
echo -ne "
-------------------------------------------------------------------------
  ██████╗ ██████╗   ████████   ██████╗  ████████
 ██╔════╝ ██╔══██╗ ██║     ██ ██╔════╝ ██║     ██
 ██║      ██████╔╝ ██║     ██ ██║      ██║     ██
 ██║      ██╔══██╗ ██║     ██ ██║      ██║     ██
 ╚██████╗ ██║  ██║  ████████  ╚██████╗  ████████
  ╚═════╝ ╚═╝  ╚═╝  ╚══════╝   ╚═════╝  ╚══════╝
------------------------------------------------------------------------
"
}
ilesystem () {
echo -ne "
Wybierz system blikow do boot i root
"
options=("ext4" "exit")
select_option $? 1 "${options[@]}"

case $? in
0) set_option FS ext4;;
1) exit ;;
*) echo "Wrong option please select again"; filesystem;;
esac
}
timezone () {
# Added this from arch wiki https://wiki.archlinux.org/title/System_time
time_zone="$(curl --fail https://ipapi.co/timezone)"
echo -ne "
System wykryl twoja strefe czasowa '$time_zone' \n"
echo -ne "Jest to poprawne?
" 
options=("tak" "nie")
select_option $? 1 "${options[@]}"

case ${options[$?]} in
    t|Y|tak|Tak|TAK)
    echo "${time_zone} ustawiono strefe"
    set_option TIMEZONE $time_zone;;
    n|N|nie|NIE|Nie)
    echo "podaj swoja strefe czasowa np. Europe/London :" 
    read new_timezone
    echo "${new_timezone} ustawiono strefe"
    set_option TIMEZONE $new_timezone;;
    *) echo "zla opcja sprobuj ponownie";timezone;;
esac
}
keymap () {
echo -ne "
Wybbierz uklad klawiatury z tej listy"
# These are default key maps as presented in official arch repo archinstall
options=(us pl uk)

select_option $? 4 "${options[@]}"
keymap=${options[$?]}

echo -ne "twoj uklad klawiatury: ${keymap} \n"
set_option KEYMAP $keymap
}

drivessd () {
echo -ne "
To jest ssd? tak/nie:
"

options=("Tak" "Nie")
select_option $? 1 "${options[@]}"

case ${options[$?]} in
    t|T|tak|Tak|TAK)
    set_option MOUNT_OPTIONS "noatime,compress=zstd,ssd,commit=120";;
    n|N|nie|NIE|Nie)
    set_option MOUNT_OPTIONS "noatime,compress=zstd,commit=120";;
    *) echo "Zla opcja. sprobuj ponownie";drivessd;;
esac
}
diskpart () {
echo -ne "
------------------------------------------------------------------------
    Ten program formatuje i usuwa wszystkie pliki na tym dysku.
    Być ostrozny po tej operacji nie da sie przywrocic danych!
------------------------------------------------------------------------

"

PS3='
Wybierz dysk do instalacji:  '
options=($(lsblk -n --output TYPE,KNAME,SIZE | awk '$1=="disk"{print "/dev/"$2"|"$3}'))

select_option $? 1 "${options[@]}"
disk=${options[$?]%|*}

echo -e "\n${disk%|*} wybrany \n"
    set_option DISK ${disk%|*}

drivessd
}
serinfo () {
read -p "Pdaj nazwe urzytkownika: " username
set_option USERNAME ${username,,} # convert to lower case as in issue #109 
set_password "PASSWORD"
read -rep "Podaj haslo: " nameofmachine
set_option NAME_OF_MACHINE $nameofmachine
}
aurhelper () {
  # Let the user choose AUR helper from predefined list
  echo -ne "Pdaj pozadany AUR helper:\n"
  options=(paru yay picaur aura trizen pacaur none)
  select_option $? 4 "${options[@]}"
  aur_helper=${options[$?]}
  set_option AUR_HELPER $aur_helper
}
desktopenv () {
  # Let the user choose Desktop Enviroment from predefined list
  echo -ne "Wybierz pozadane srodowisko pulpitu:\n"
  options=( `for f in pkg-files/*.txt; do echo "$f" | sed -r "s/.+\/(.+)\..+/\1/;/pkgs/d"; done` )
  select_option $? 4 "${options[@]}"
  desktop_env=${options[$?]}
  set_option DESKTOP_ENV $desktop_env
}
installtype () {
  echo -ne "Wybierz typ instalacji:\n\n
  Pelna istalacja: Instalacja wszystkich komponentow potrzebnych na codzien\n
  Minimalna instalacja: Instalacja tylko nezbednych aplikacji\n"
  options=(FULL MINIMAL)
  select_option $? 4 "${options[@]}"
  install_type=${options[$?]}
  set_option INSTALL_TYPE $install_type
}
checks
clear
logo
userinfo
clear
logo
desktopenv
# Set fixed options that installation uses if user choses server installation
set_option INSTALL_TYPE MINIMAL
set_option AUR_HELPER NONE
if [[ ! $desktop_env == server ]]; then
  clear
  logo
  aurhelper
  clear
  logo
  installtype
fi
clear
logo
diskpart
clear
logo
filesystem
clear
logo
timezone
clear
logo
keymap