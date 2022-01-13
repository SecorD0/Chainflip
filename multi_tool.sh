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
		echo -e "  -h,  --help          show the help page"
		echo -e "  -ai, --auto-install  the node auto installation"
		echo -e "  -up, --update        the node auto installation"
		echo -e "  -un, --uninstall     the node auto installation"
		echo
		echo -e "${C_LGn}Useful URLs${RES}:"
		echo -e "https://github.com/SecorD0/Chainflip/blob/main/multi_tool.sh — script URL"
		echo -e "https://teletype.in/@letskynode/Chainflip_EN — English-language a node installation guide"
		echo -e "https://teletype.in/@letskynode/Chainflip_RU — Russian-language a node installation guide"
		echo -e "https://t.me/letskynode — node Community"
		echo -e "https://teletype.in/@letskynode — guides and articles"
		echo
		return 0 2>/dev/null; exit 0
		;;
	-ai|--auto-install)
		function="auto_install"
		shift
		;;
	-up|--update)
		function="update"
		shift
		;;
	-un|--uninstall)
		function="uninstall"
		shift
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
	mv $HOME/chainflip-*/ $HOME/chainflip_bin/
	#wget -qO $HOME/chainflip_bin/subkey "https://github.com/chainflip-io/chainflip-bin/releases/download/${chainflip_version}/subkey"
	wget -qO $HOME/chainflip_bin/subkey "https://github.com/chainflip-io/chainflip-bin/releases/download/v0.1.0-soundcheck/subkey"
	chmod +x $HOME/chainflip_bin/subkey $HOME/chainflip_bin/chainflip-*
	mv $HOME/chainflip_bin/* /usr/bin/
	rm -rf $HOME/chainflip_bin/
}
auto_install() {
	printf "${C_LGn}Enter Websocket RPC:${RES} "
	local rpc
	read -r rpc
	
	# ethereum_key_file
	mkdir -p $HOME/chainflip/ $HOME/chainflip_backup
	if [ ! -f $HOME/chainflip_backup/ethereum_key_file ]; then
		printf "${C_LGn}Enter Etherium wallet private key:${RES} "
		local pk
		read -r pk
		echo "$pk" | sed 's%0x%%' | tr -d '\n' > $HOME/chainflip_backup/ethereum_key_file
	fi
	cp $HOME/chainflip_backup/ethereum_key_file $HOME/chainflip/
	
	# Binary
	if [ ! -f /usr/bin/chainflip-node ] || [ ! -f /usr/bin/chainflip-engine ]; then
		install
	fi	
	
	# signing_key_file
	if [ ! -f $HOME/chainflip_backup/signing_key_file ]; then
		if [ ! -f $HOME/chainflip_backup/signing_key.txt ]; then
			printf_n "${C_LGn}Generating new signing key${RES}" 
			subkey generate | tee -a $HOME/chainflip_backup/signing_key.txt
		fi
		. <(wget -qO- https://raw.githubusercontent.com/SecorD0/utils/main/miscellaneous/insert_variable.sh) -n chainflip_validator -v `awk 'NR == 5 {printf $(NF)}' $HOME/chainflip_backup/signing_key.txt`
		awk 'NR == 2 {printf $(NF)}' $HOME/chainflip_backup/signing_key.txt | sed 's%0x%%' > $HOME/chainflip_backup/signing_key_file
	fi
	cp $HOME/chainflip_backup/signing_key_file $HOME/chainflip/
	
	# node_key_file
	if [ ! -f $HOME/chainflip_backup/node_key_file ]; then
		if [ ! -f $HOME/chainflip_backup/node_key.txt ]; then
			printf_n "${C_LGn}Generating new node key${RES}" 
			echo -e "`subkey generate-node-key 2>&1`" | tee -a $HOME/chainflip_backup/node_key.txt
		fi
		awk 'NR == 2 {printf $1}' $HOME/chainflip_backup/node_key.txt > $HOME/chainflip_backup/node_key_file
	fi
	cp $HOME/chainflip_backup/node_key_file $HOME/chainflip/
	
	# Service files
	sudo tee <<EOF >/dev/null $HOME/chainflip/Default.toml
[node_p2p]
node_key_file = "$HOME/chainflip/node_key_file"

[state_chain]
ws_endpoint = "ws://127.0.0.1:9944"
signing_key_file = "$HOME/chainflip/signing_key_file"

[eth]
from_block = 9810000
node_endpoint = "$rpc"
private_key_file = "$HOME/chainflip/ethereum_key_file"

[health_check]
hostname = "0.0.0.0"
port = 5555

[signing]
db_file = "data.db"
EOF
	sudo tee <<EOF >/dev/null /etc/systemd/system/chainflipnd.service
[Unit]
Description=Chainflip Validator Node

[Service]
User=$USER
ExecStart=`which chainflip-node` \\
  --chain soundcheck \\
  --base-path $HOME/chainflip/chaindata \\
  --node-key-file $HOME/chainflip/node_key_file \\
  --in-peers 500 \\
  --out-peers 500 \\
  --port 30333 \\
  --validator \\
  --ws-max-out-buffer-capacity 3000 \\
  --bootnodes /ip4/165.22.70.65/tcp/30333/p2p/12D3KooW9yoE6qjRG9Bp5JB2JappsU9V5bck1nUDSNRR2ye3dFbU
Restart=on-failure
RestartSec=3
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF
	sudo tee <<EOF >/dev/null /etc/systemd/system/chainfliped.service
[Unit]
Description=Chainflip Validator Engine

[Service]
User=$USER
ExecStart=`which chainflip-engine` --config-path $HOME/chainflip/Default.toml
Restart=on-failure
RestartSec=3
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF
	sudo systemctl daemon-reload
	sudo systemctl enable chainflipnd chainfliped
	sudo systemctl restart chainflipnd chainfliped
	. <(wget -qO- https://raw.githubusercontent.com/SecorD0/utils/main/miscellaneous/insert_variable.sh) -n chainflip_node_log -v "sudo journalctl -fn 100 -u chainflipnd" -a
	. <(wget -qO- https://raw.githubusercontent.com/SecorD0/utils/main/miscellaneous/insert_variable.sh) -n chainflip_engine_log -v "sudo journalctl -fn 100 -u chainfliped" -a
	. <(wget -qO- https://raw.githubusercontent.com/SecorD0/utils/main/logo.sh)
	printf_n "
The node was ${C_LGn}launched${RES}.
Remember to save files in this directory:
${C_LR}$HOME/chainflip_backup/${RES}

\tv ${C_LGn}Useful commands${RES} v

To view the node log: ${C_LGn}chainflip_node_log${RES}
To view the engine log: ${C_LGn}chainflip_engine_log${RES}
To restart the node: ${C_LGn}sudo systemctl restart chainflipnd${RES}
To restart the engine: ${C_LGn}sudo systemctl restart chainfliped${RES}
"
}
update() {
	printf_n "${C_LGn}Node updating...${RES}"
	sudo systemctl stop chainflipnd chainfliped
	install
	sudo systemctl restart chainflipnd chainfliped
	printf_n "${C_LGn}Done!${RES}"
}
uninstall() {
	printf_n "${C_LGn}Node uninstalling...${RES}"
	sudo systemctl stop chainflipnd chainfliped
	rm -rf `which chainflip-node` `which chainflip-engine` $HOME/chainflip /etc/systemd/system/chainflip*.service
	sudo systemctl daemon-reload
	. <(wget -qO- https://raw.githubusercontent.com/SecorD0/utils/main/miscellaneous/insert_variable.sh) -n chainflip_node_log -da
	. <(wget -qO- https://raw.githubusercontent.com/SecorD0/utils/main/miscellaneous/insert_variable.sh) -n chainflip_engine_log -da
	. <(wget -qO- https://raw.githubusercontent.com/SecorD0/utils/main/miscellaneous/insert_variable.sh) -n chainflip_validator -da
	printf_n "${C_LGn}Done!${RES}"
}

# Actions
cd
sudo apt install wget -y &>/dev/null
. <(wget -qO- https://raw.githubusercontent.com/SecorD0/utils/main/logo.sh)
$function
