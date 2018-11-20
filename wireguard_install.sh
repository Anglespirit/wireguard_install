#!/usr/bin/env bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH=$PATH
#=================================================
#	System Required: CentOS 6+/Debian 6+/Ubuntu 14.04+
#	Description: Install the WireGuard
#	Version: 1.0.0
#	Author: AngelRE
#	Blog: https://liveforlove.club
#=================================================

sh_ver="1.0.0"
wg_folder="/etc/wireguard"
wg_file="${wg_folder}/wg0.conf"
wg_log_file="${wg_folder}/wgserver.log"
Green_font_prefix="\033[32m" && Red_font_prefix="\033[31m" && Green_background_prefix="\033[42;37m" && Red_background_prefix="\033[41;37m" && Font_color_suffix="\033[0m"
Info="${Green_font_prefix}[信息]${Font_color_suffix}"
Error="${Red_font_prefix}[错误]${Font_color_suffix}"
Tip="${Green_font_prefix}[注意]${Font_color_suffix}"
Separator_1="——————————————————————————————"

#检查root权限
check_root(){
        [[ $EUID!=0 ]] && echo -e "${Error} 当前账号非ROOT(或没有ROOT权限)，无法继续操作，请使用 ${Green_background_prefix} sudo su ${Font_color_suffix} 来获取临时ROOT权限（执行后会提示输入当前账号的密码）。" && exit 1
}
#检测系统
check_sys(){
	if [[ -e /etc/redhat-release ]]; then
		if [[ cat /etc/centos-release | grep -q -E -i "release 6" ]]; then
			release="centos6"
		elif [[ cat /etc/centos-release | grep -q -E -i "release 7" ]]; then
			release="centos7"
		else 
			echo -e "暂不支持您的版本，请等待下次更新，万分抱歉！"
		fi
	elif cat /etc/issue | grep -q -E -i "debian"; then
		release="debian"
	elif cat /etc/issue | grep -q -E -i "ubuntu"; then
		release="ubuntu"
	elif cat /etc/issue | grep -q -E -i "centos|red hat|redhat"; then
		release="centos"
	elif cat /proc/version | grep -q -E -i "debian"; then
		release="debian"
	elif cat /proc/version | grep -q -E -i "ubuntu"; then
		release="ubuntu"
	elif cat /proc/version | grep -q -E -i "centos|red hat|redhat"; then
		release="centos"
    fi
	bit=`uname -m`
	serverip=$(curl icanhazip.com)
}
#更新内核
update_kernel(){
	if [[ ${release} == "centos7" ]]; then
		yum -y install epel-release   #安装epel
		sed -i "0,/enabled=0/s//enabled=1/" /etc/yum.repos.d/epel.repo
		yum remove -y kernel-devel   
		rpm --import https://www.elrepo.org/RPM-GPG-KEY-elrepo.org
		rpm -Uvh http://www.elrepo.org/elrepo-release-7.0-2.el7.elrepo.noarch.rpm
		yum --disablerepo="*" --enablerepo="elrepo-kernel" list available
		yum -y --enablerepo=elrepo-kernel install kernel-ml
		sed -i "s/GRUB_DEFAULT=saved/GRUB_DEFAULT=0/" /etc/default/grub
		grub2-mkconfig -o /boot/grub2/grub.cfg
		wget http://elrepo.org/linux/kernel/el7/x86_64/RPMS/kernel-ml-devel-4.18.12-1.el7.elrepo.x86_64.rpm
		rpm -ivh kernel-ml-devel-4.18.12-1.el7.elrepo.x86_64.rpm
		yum -y --enablerepo=elrepo-kernel install kernel-ml-devel
		
	elif [[ ${release} == "centos6" ]]; then
	
	elif [[ ${release} == "ubuntu" ]]; then
		
	elif [[ ${release} == "debian" ]]; then
	
fi
    read -p "需要重启以应用更改，再次执行脚本选择安装wireguard，是否现在重启 ? [Y/n] :" yn
	[ -z "${yn}" ] && yn="y"
	if [[ $yn == [Yy] ]]; then
		echo -e "${Info} 重启中..."
		reboot
	fi
}
#安装wireguard
install_WG(){
	if [[ ${release} == "centos" ]]; then
		yum upgrade
		echo -e "正在安装额外软件包(Epel)"
		curl -Lo /etc/yum.repos.d/wireguard.repo https://copr.fedorainfracloud.org/coprs/jdoss/wireguard/repo/epel-7/jdoss-wireguard-epel-7.repo
		#yum install epel-release
		echo -e "正在安装Wireguard"
		yum -y install wireguard-dkms wireguard-tools
	elif [[ ${release} == "ubuntu" ]]; then
		echo -e "${Info} 安装依赖..."
		add-apt-repository ppa:wireguard/wireguard
		apt-get update
		apt-get -y install wireguard
	elif [[ ${release} == "debian" ]]; then
		echo -e "${Info} 安装依赖..."
		echo "deb http://deb.debian.org/debian/ unstable main" &gt; /etc/apt/sources.list.d/unstable.list
		printf 'Package: *\nPin: release a=unstable\nPin-Priority: 90\n' &gt; /etc/apt/preferences.d/limit-unstable
		apt update
		apt install wireguard
	else
		echo -e "其他版本请待下次更新，万分抱歉！" && exit 1
	fi
	echo -e "安装完成，运行脚本以启动" && exit 1
}
#查看配置
view_conf(){
	cat /etc/wireguard/wg0.conf && exit 1
}
#更改配置
change_wg(){
	yum install vim
	vim /etc/wireguard/wg0.conf
}
#启动wireguard
start_wg(){
	cd /etc/wireguard
	if [[ !-e ./wg0.conf ]];then
		Get_key
		umask 077
		Set_port
		Set_address
		cat > ./wg0.conf <<-EOF
		[Interface]
		PrivateKey = ${serviceprivatekey}
		Address = ${wg_address} 
		DNS = 1.1.1.1
		MTU = 1450
		[Peer]
		PublicKey = ${clientpublickey}
		Endpoint = ${serverip}:${wg_port}
		AllowedIPs = 0.0.0.0/0, ::0/0
		PersistentKeepalive = 25
		EOF
		Add_iptables
		Save_iptables
		Set_iptables
		
		#开启net转发
		systemctl -w net.ipv4.ip_forward=1
		Set_client
		wg-quick up wg0
		systemctl enable wg-quick@wg0
		cat ./client.conf && exit 1
	else
		wg-quick up wg0
		systemctl enable wg-quick@wg0
		cat ./client.conf && exit 1
	fi
}
#查看用户
user_status(){
}
#卸载wireguard
uninstall_wg(){
	yum remove wireguard-dkms wireguard-tools
}
#查看日志
view_log(){

}
#获取wg的PID
check_pid(){
	PID=`ps -ef |grep -v grep | grep wg |awk '{print $2}'`
}
#生成双密钥
get_key(){
	wg genkey | sudo tee -a /etc/wireguard/serviceprivatekey | wg pubkey | sudo tee /etc/wireguard/servicepublickey
	wg genkey | sudo tee -a /etc/wireguard/clientprivatekey | wg pubkey | sudo tee /etc/wireguard/clientpublickey
	serviceprivatekey=$(cat serviceprivatekey)
	servicepublickey=$(cat servicepublickey)
	clientprivatekey=$(cat clientprivatekey)
	clientpublickey=$(cat clientpublickey)
}
# 设置 防火墙规则
add_iptables(){
	iptables -I INPUT -m state --state NEW -m tcp -p tcp --dport ${wg_port} -j ACCEPT
	iptables -I INPUT -m state --state NEW -m udp -p udp --dport ${wg_port} -j ACCEPT
	ip6tables -I INPUT -m state --state NEW -m tcp -p tcp --dport ${wg_port} -j ACCEPT
	ip6tables -I INPUT -m state --state NEW -m udp -p udp --dport ${wg_port} -j ACCEPT
}
del_iptables(){
	iptables -D INPUT -m state --state NEW -m tcp -p tcp --dport ${wg_port} -j ACCEPT
	iptables -D INPUT -m state --state NEW -m udp -p udp --dport ${wg_port} -j ACCEPT
	ip6tables -D INPUT -m state --state NEW -m tcp -p tcp --dport ${wg_port} -j ACCEPT
	ip6tables -D INPUT -m state --state NEW -m udp -p udp --dport ${wg_port} -j ACCEPT
}
save_iptables(){
	if [[ ${release} == "centos" ]]; then
		service iptables save
		service ip6tables save
	else
		iptables-save > /etc/iptables.up.rules
		ip6tables-save > /etc/ip6tables.up.rules
	fi
}
set_iptables(){
	if [[ ${release} == "centos" ]]; then
		service iptables save
		service ip6tables save
		chkconfig --level 2345 iptables on
		chkconfig --level 2345 ip6tables on
	else
		iptables-save > /etc/iptables.up.rules
		ip6tables-save > /etc/ip6tables.up.rules
		echo -e '#!/bin/bash\n/sbin/iptables-restore < /etc/iptables.up.rules\n/sbin/ip6tables-restore < /etc/ip6tables.up.rules' > /etc/network/if-pre-up.d/iptables
		chmod +x /etc/network/if-pre-up.d/iptables
	fi
}
#设置端口
set_port(){
	while true
	do
	echo -e "请输入要监听的服务器端口"
	stty erase '^H' && read -p "(默认: 2333):" wg_port
	[[ -z "$wg_port" ]] && wg_port="2333"
	expr ${wg_port} + 0 &>/dev/null
	if [[ $? == 0 ]]; then
		if [[ ${wg_port} -ge 1 ]] && [[ ${wg_port} -le 65535 ]]; then
			echo && echo ${Separator_1} && echo -e "	端口 : ${Green_font_prefix}${wg_port}${Font_color_suffix}" && echo ${Separator_1} && echo
			break
		else
			echo -e "${Error} 请输入正确的数字(1-65535)"
		fi
	else
		echo -e "${Error} 请输入正确的数字(1-65535)"
	fi
	done
}
#设置内网地址
set_address(){
	while true
	do
	echo -e "请输入本机的内网地址"
	stty erase '^H' && read -p "(默认: 10.0.0.1/24):" wg_address
	[[ -z "$wg_address" ]] && wg_address="10.0.0.1/24"
	done
}
#设置DNS
#设置广告过滤
#设置自动保存
set_save(){
	while true
	do
	echo -e "是否自动保存配置(本操作保留当前环境配置，覆盖原有的文件)"
	stty erase '^H' && read -p "(默认: true):" wg_save
	[[ -z "$wg_save" ]] && wg_save="true"
	done
}
#客户端配置
set_client(){
if [[ !-e ./client.conf ]];then
	cat > ./client.conf <<-EOF
	[Interface]
	PrivateKey = ${clientprivatekey}
	Address = 10.0.0.2/24 
	DNS = 8.8.8.8
	MTU = 1420
	[Peer]
	PublicKey = ${servicepublickey}
	Endpoint = ${serverip}:${wg_port}
	AllowedIPs = 0.0.0.0/0, ::0/0
	PersistentKeepalive = 25
	EOF
else
	rm -f ./client.conf
}
#关闭wireguard
stop(){
	systemctl stop wg-quick@wg0
}
#Start menu
start_menu
check_root
echo && stty erase '^H' && read -p "请输入数字 [1-15]：" num
case "$num" in
	1)
	update_kernel
	2)
	install_wg
	;;
	3)
	start_wg
	;;
	4)
	view_conf
	;;
	5)
	change_wg
	;;
	6)
	user_status
	;;
	7)
	uninstall_wg
	;;
	8)
	view_log
	;;
	9)
	stop
	;;
	*)
	echo -e "${Error} 请输入正确的数字 [1-8]"
	;;
esac
