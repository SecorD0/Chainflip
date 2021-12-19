#!/bin/bash
# Default variables
function="install"

# Options
. <(wget -qO- https://raw.githubusercontent.com/SecorD0/utils/main/colors.sh) --
option_value(){ echo "$1" | sed -e 's%^--[^=]*=%%g; s%^-[^=]*=%%g'; }
while test $# -gt 0; do
	case "$1" in
	-h|--help)
		. <(wget -qO- https://raw.githubusercontent.com/SecorD0/utils/main/logo.sh)
		echo
		echo -e "${C_LGn}Functionality${RES}: the script performs many actions related to a Chainflip node"
		echo
		echo -e "${C_LGn}Usage${RES}: script ${C_LGn}[OPTIONS]${RES}"
		echo
		echo -e "${C_LGn}Options${RES}:"
		echo -e "  -h,  --help  show the help page"
		echo
		echo -e "${C_LGn}Useful URLs${RES}:"
		echo -e "https://github.com/SecorD0/Chainflip/blob/main/multi_tool.sh - script URL"
		echo -e "https://teletype.in/@letskynode/Chainflip_RU — Russian-language a node installation guide"
		echo -e "https://t.me/letskynode — node Community"
		echo -e "https://teletype.in/@letskynode — guides and articles"
		echo
		return 0 2>/dev/null; exit 0
		;;
	*|--)
		break
		;;
	esac
done
# Functions
printf_n(){ printf "$1\n" "${@:2}"; }
install() {
	sudo apt update
	sudo apt upgrade -y
	sudo apt install wget jq -y
	local chainflip_version=`wget -qO- https://api.github.com/repos/chainflip-io/chainflip-bin/releases/latest | jq -r ".tag_name"`
	wget -q "https://github.com/chainflip-io/chainflip-bin/releases/download/${chainflip_version}/chainflip.tar.gz"
	tar -xvf $HOME/chainflip.tar.gz
	rm -rf $HOME/chainflip.tar.gz
	mv $HOME/chainflip* $HOME/chainflip_bin
	wget -qO $HOME/chainflip_bin/subkey "https://github.com/chainflip-io/chainflip-bin/releases/download/${chainflip_version}/subkey"
	chmod +x $HOME/chainflip_bin/subkey $HOME/chainflip_bin/chainflip-*
	mv $HOME/chainflip_bin/* /usr/bin/
	rm -rf $HOME/chainflip_bin/
}
auto_install() {
	echo
}

# Actions
cd
sudo apt install wget -y &>/dev/null
. <(wget -qO- https://raw.githubusercontent.com/SecorD0/utils/main/logo.sh)
$function
