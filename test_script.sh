#!/usr/bin/env bash
# https://openwrt.org/docs/guide-user/virtualization/qemu#openwrt_in_qemu_x86-64

# 取得 OpenWrt 的最新穩定版本
response=$(curl -s https://openwrt.org)
stableversion=$(echo "$response" | sed -n 's/.*Current stable release - OpenWrt \([0-9.]\+\).*/\1/p' | head -n 1)
# 下載 OpenWrt 映像的 URL
URL="https://downloads.openwrt.org/releases/$stableversion/targets/x86/64/openwrt-$stableversion-x86-64-generic-ext4-combined-efi.img.gz"
# 下載 OpenWrt 映像黨
wget -q --show-progress $URL

# 虛擬機配置
VMID=100
VMNAME="OpenWrt"
STORAGEID=$(grep "content images" -B 3 /etc/pve/storage.cfg | awk 'NR==1{print $2}')
CORES=1
MEMORY=256
PCIID=$(lspci | grep Network | awk '{print $1}')

# 解壓並調整磁碟映像大小
gunzip openwrt-*.img.gz
qemu-img resize -f raw openwrt-*.img 512M

# 安裝 parted
if ! command -v parted &> /dev/null
then
    echo "parted 未安装，正在安装..."
    apt install -y parted
else
    echo "parted 已安装"
fi

# 取得未使用磁碟裝置位置
loop_device=$(losetup -f)

# 掛載映像
losetup $loop_device openwrt-*.img
# 擴展第二磁區
parted -f -s "$loop_device" resizepart 2 100%
# 擴展檔案系統
resize2fs ${loop_device}p2
# 解除掛載磁碟
losetup -d $loop_device

# 創建虛擬機
qm create $VMID --name $VMNAME -ostype l26 --machine q35 --bios ovmf --scsihw virtio-scsi-single \
  --cores $CORES --cpu host --memory $MEMORY --net0 virtio,bridge=vmbr0 --net1 virtio,bridge=vmbr1 --net2 virtio,bridge=vmbr2 --net3 virtio,bridge=vmbr3 --onboot 1

# 將磁碟映像匯入 Proxmox 儲存空間
qm importdisk $VMID openwrt-*.img $STORAGEID
qm set $VMID --scsi0 $STORAGEID:vm-$VMID-disk-0 --boot order=scsi0 --hostpci0 $PCIID,pcie=1

# 啟動虛擬機
qm start $VMID

# 這個函數會根據QEMU的鍵盤編碼將文字轉換為sendkey命令
qm_sendline() {
    local text="$1"     # 要轉換的文字
    # 創建一個鍵位對應表，去掉了小寫字母和數字
    declare -A key_map=(
        ['A']='shift-a'
        ['B']='shift-b'
        ['C']='shift-c'
        ['D']='shift-d'
        ['E']='shift-e'
        ['F']='shift-f'
        ['G']='shift-g'
        ['H']='shift-h'
        ['I']='shift-i'
        ['J']='shift-j'
        ['K']='shift-k'
        ['L']='shift-l'
        ['M']='shift-m'
        ['N']='shift-n'
        ['O']='shift-o'
        ['P']='shift-p'
        ['Q']='shift-q'
        ['R']='shift-r'
        ['S']='shift-s'
        ['T']='shift-t'
        ['U']='shift-u'
        ['V']='shift-v'
        ['W']='shift-w'
        ['X']='shift-x'
        ['Y']='shift-y'
        ['Z']='shift-z'
        [' ']='spc'
        ['`']='grave_accent'
        ['~']='shift-grave_accent'
        ['!']='shift-1'
        ['@']='shift-2'
        ['#']='shift-3'
        ['$']='shift-4'
        ['%']='shift-5'
        ['^']='shift-6'
        ['&']='shift-7'
        ['*']='shift-8'
        ['(']='shift-9'
        [')']='shift-0'
        ['-']='minus'
        ['_']='shift-minus'
        ['=']='equal'
        ['+']='shift-equal'
        ['[']='bracket_left'
        ['{']='shift-bracket_left'
        [']']='bracket_right'
        ['}']='shift-bracket_right'
        ['\']='backslash'
        ['|']='shift-backslash'
        [';']='semicolon'
        [':']='shift-semicolon'
        ["'"]='apostrophe'
        ['"']='shift-apostrophe'
        [',']='comma'
        ['<']='shift-comma'
        ['.']='dot'
        ['>']='shift-dot'
        ["/"]='slash'
        ['?']='shift-slash'
    )

    # 遍歷輸入文字，並發送對應的sendkey命令
    for (( i=0; i<${#text}; i++ )); do
        char=${text:$i:1}
        if [[ -v key_map[$char] ]]; then
            key=${key_map[$char]}
            qm sendkey $VMID $key
        else
            qm sendkey $VMID $char
        fi
    done
    qm sendkey $VMID ret
}

# 用法示例
#send_keys 100 "Aa \`~!@#$%^&*()-_=+[{]}\\|;:'\",<.>/?"

# 等待虛擬機開機完成
echo "等待虛擬機開機完成"
sleep 20

# 輸入 enter 進入命令列
qm_sendline ""

echo "刪除默認 WAN 配置"
qm_sendline "uci delete network.@device[0]"
echo "設定 eth0 作為 WAN 接口，並設置它自動獲取 IP（使用 DHCP）。"
qm_sendline "uci set network.wan=interface"
qm_sendline "uci set network.wan.ifname=eth0"
qm_sendline "uci set network.wan.proto=dhcp"
echo "設定 eth1, eth2, eth3 為 LAN 接口，並設定為靜態 IP 配置。這些接口都會屬於同一個子網，並將 IP 設置為 192.168.2.x 範圍，並且設定路由器管理 IP 為 192.168.2.1。"
qm_sendline "uci set network.lan=interface"
qm_sendline "uci set network.lan.type=bridge"
qm_sendline "uci set network.lan.ifname=eth1 eth2 eth3"
qm_sendline "uci set network.lan.proto=static"
qm_sendline "uci set network.lan.ipaddr=192.168.2.1"
qm_sendline "uci set network.lan.netmask=255.255.255.0"
echo "設置 DHCP 服務，使其在 192.168.2.100 開始自動分配 IP 地址，並且分配範圍為 192.168.2.100 至 192.168.2.199。"
qm_sendline "uci set dhcp.lan=dhcp"
qm_sendline "uci set dhcp.lan.interface=lan"
qm_sendline "uci set dhcp.lan.start=100"
qm_sendline "uci set dhcp.lan.limit=100"
qm_sendline "uci set dhcp.lan.leasetime=12h"
echo "保存配置並重新啟動網絡服務，使更改生效。"
qm_sendline "uci commit network"
qm_sendline "service network restart"
echo "更新套件清單。"
qm_sendline "opkg update"
echo "安裝繁體中文。"
qm_sendline "opkg install luci-i18n-base-zh-tw"
echo "安裝 PCIe 驅動。"
qm_sendline "opkg install pciutils"
echo "安裝 MT7921 驅動。"
qm_sendline "opkg install kmod-mt7921e"
echo "安裝 MT7922 韌體。"
qm_sendline "opkg install kmod-mt7922-firmware"
echo "安裝無線網路套件。"
qm_sendline "opkg install wpad-openssl"
echo "安裝藍芽套件。"
qm_sendline "opkg install bluez-daemon"
echo "安裝藍芽韌體。"
qm_sendline "opkg install mt7922bt-firmware"
echo "安裝 Qemu-guest-agent 套件。"
qm_sendline "opkg install qemu-ga"
echo "安裝 ACPI 電源套件。"
qm_sendline "opkg install acpid"
echo "設定無線網路 5GHz 與密碼open1234。"
qm_sendline "uci set wireless.radio0.disabled=0"
qm_sendline "uci set wireless.radio0.channel=auto"
qm_sendline "uci set wireless.radio0.htmode=HE80"
qm_sendline "uci set wireless.radio0.country=TW"
qm_sendline "uci set wireless.radio0.hwmode=11a"
qm_sendline "uci set wireless.default_radio0.network=lan"
qm_sendline "uci set wireless.default_radio0.mode=ap"
qm_sendline "uci set wireless.default_radio0.ssid=OpenWrt"
qm_sendline "uci set wireless.default_radio0.encryption=sae"
qm_sendline "uci set wireless.default_radio0.key=open1234"
qm_sendline "sed -i '/exit 0/i\\sleep 10 && wifi' /etc/rc.local"
echo "保存配置並重新啟動無線網絡服務，使更改生效。"
qm_sendline "uci commit wireless"
qm_sendline "service wireless restart"
echo "安裝佈景主題。"
qm_sendline "ipk_url=$(curl -s https://api.github.com/repos/jerrykuku/luci-theme-argon/releases | grep '\"browser_download_url\":' | grep 'luci-theme-argon.*_all\\.ipk' | sed -n 's/.*\"browser_download_url\": \"\\([^\"]*\\)\".*/\\1/p' | head -n 1)"
qm_sendline "opkg install luci-compat"
qm_sendline "opkg install luci-lib-ipkg"
qm_sendline "wget -O luci-theme-argon.ipk $ipk_url"
qm_sendline "opkg install luci-theme-argon.ipk"
qm_sendline "rm -rf luci-theme-argon.ipk" 
echo "重啟虛擬機。"
qm_sendline "reboot"

# 清理下載的 OpenWrt 映像文件
rm -rf openwrt-*.img
