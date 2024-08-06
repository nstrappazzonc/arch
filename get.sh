#!/usr/bin/env sh
set -eu

declare -A osPMS;
declare platform;
declare arch;

main() {
    platform="$(uname -s)"
    arch="$(uname -m)"
    banner
    check_is_not_root
    check_valid_platform
    check_valid_platform_architecture
    check_exist_curl_or_wget
    tmp="$(mktemp -d "/tmp/strappazzon-XXXXXX")"
    pms=($(package_manager_system))

    echo "OS: ${platform}-${arch}"
    echo "Package manager: ${pms}"
    echo "Parameters: $@"
    echo ""

    if [ "$#" -eq 1 ]; then
        run_script $1
        exit 0
    fi

    run_script "os/${pms}/packages"
    run_script "os/${pms}/yay"
    run_script "os/${pms}/docker"
    run_script "profile/git"
    run_script "profile/inputrc"
    run_script "profile/bashrc"
}

banner() {
    reset
    clear
    echo ""
    echo " ███████╗████████╗██████╗  █████╗ ██████╗ ██████╗  █████╗ ███████╗███████╗ ██████╗ ███╗   ██╗   ███╗   ███╗███████╗"
    echo " ██╔════╝╚══██╔══╝██╔══██╗██╔══██╗██╔══██╗██╔══██╗██╔══██╗╚══███╔╝╚══███╔╝██╔═══██╗████╗  ██║   ████╗ ████║██╔════╝"
    echo " ███████╗   ██║   ██████╔╝███████║██████╔╝██████╔╝███████║  ███╔╝   ███╔╝ ██║   ██║██╔██╗ ██║   ██╔████╔██║█████╗  "
    echo " ╚════██║   ██║   ██╔══██╗██╔══██║██╔═══╝ ██╔═══╝ ██╔══██║ ███╔╝   ███╔╝  ██║   ██║██║╚██╗██║   ██║╚██╔╝██║██╔══╝  "
    echo " ███████║   ██║   ██║  ██║██║  ██║██║     ██║     ██║  ██║███████╗███████╗╚██████╔╝██║ ╚████║██╗██║ ╚═╝ ██║███████╗"
    echo " ╚══════╝   ╚═╝   ╚═╝  ╚═╝╚═╝  ╚═╝╚═╝     ╚═╝     ╚═╝  ╚═╝╚══════╝╚══════╝ ╚═════╝ ╚═╝  ╚═══╝╚═╝╚═╝     ╚═╝╚══════╝"
    echo ""
}

check_is_not_root() {
    if [[ $EUID -eq 0 ]]; then
        echo "This script must be run as not root"
        exit 1
    fi
}

check_valid_platform() {
    if [ "$platform" = "Darwin" ]; then
        platform="macos"
    elif [ "$platform" = "Linux" ]; then
        platform="linux"
    else
        echo "Unsupported platform $platform"
        exit 1
    fi
}

check_valid_platform_architecture() {
    case "$platform-$arch" in
        macos-arm64* | linux-arm64* | linux-armhf | linux-aarch64)
            arch="aarch64"
            ;;
        macos-x86* | linux-x86* | linux-i686*)
            arch="x86_64"
            ;;
        *)
            echo "Unsupported platform or architecture"
            exit 1
            ;;
    esac
}

check_exist_curl_or_wget(){
    if which curl >/dev/null 2>&1; then
        curl () {
            command curl -sfL "$@"
        }
    elif which wget >/dev/null 2>&1; then
        curl () {
        wget -O- "$@"
        }
    else
        echo "Could not find; 'curl' or 'wget'"
        exit 1
    fi
}

package_manager_system() {
    osPMS[/etc/redhat-release]=yum
    osPMS[/etc/arch-release]=pacman
    osPMS[/etc/gentoo-release]=emerge
    osPMS[/etc/SuSE-release]=zypp
    osPMS[/etc/debian_version]=apt-get
    osPMS[/etc/alpine-release]=apk

    for f in ${!osPMS[@]}
    do
        if [[ -f $f ]];then
            echo "${osPMS[$f]}"
        fi
    done
}

run_script() {
    URI="https://raw.githubusercontent.com/nstrappazzonc/get/main/$1.sh"
    if curl --output /dev/null --silent --head --fail "${URI}"; then
        echo "Run script: ${URI}"
        curl -s -f -L "${URI}" | sh
    fi
}

main "$@"
