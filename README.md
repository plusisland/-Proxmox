## Proxmox VE 常用設定與安裝腳本

本指南提供一系列腳本，協助您快速設定 Proxmox VE 環境，包含移除未訂閱提示、設定非訂閱套件庫、PCIe 設備直通以及 OpenWrt 安裝。

### 1\. 移除未訂閱訊息視窗

此腳本將移除 Proxmox VE 管理介面中顯示的未訂閱訊息視窗，讓介面更簡潔。

```bash
bash -c "$(wget -qLO - https://raw.githubusercontent.com/plusisland/Proxmox_Virtual_Environment_Scripts/refs/heads/main/hide_no_valid_subscription.sh)"
```

### 2\. 設定非訂閱套件庫

此腳本將設定 Proxmox VE 的非訂閱套件庫，允許您安裝社群維護的軟體包。

```bash
bash -c "$(wget -qLO - https://raw.githubusercontent.com/plusisland/Proxmox_Virtual_Environment_Scripts/refs/heads/main/set_no_subscription_repositories.sh)"
```

### 3\. PCIe 設備直通

此腳本將協助您設定 PCIe 設備直通，允許虛擬機器直接存取實體 PCIe 設備，例如顯示卡、網卡等。  **（請注意，PCIe 直通需要硬體支援，請確認您的 CPU 和主機板支援 IOMMU）**

```bash
bash -c "$(wget -qLO - https://raw.githubusercontent.com/plusisland/Proxmox_Virtual_Environment_Scripts/refs/heads/main/set_pcie_passthrough.sh)"
```

### 4\. OpenWrt 安裝與設定

此腳本將引導您在 Proxmox VE 中建立 OpenWrt 虛擬機器，並進行相關設定。

```bash
bash -c "$(wget -qLO - https://raw.githubusercontent.com/plusisland/Proxmox_Virtual_Environment_Scripts/refs/heads/main/OpenWrt.sh)"
```

**OpenWrt 安裝完成後，請按照以下步驟進行設定：**

1.  **更新軟體列表：**

    ```bash
    opkg update
    ```

2.  **安裝中文化：**

    ```bash
    opkg install luci-i18n-base-zh-tw
    ```

3.  **安裝 PCIe 相關工具：**

    ```bash
    opkg install pciutils
    ```

4.  **安裝無線網卡驅動 (以 mt7921e 為例，請根據您的無線網卡型號選擇)：**

    ```bash
    opkg install kmod-mt7921e
    ```

5.  **安裝藍牙韌體 (若您的無線網卡支援藍牙功能，以 mt7922bt 為例)：**

    ```bash
    opkg install mt7922bt-firmware
    ```

6.  **安裝無線網卡韌體 (若您的無線網卡支援藍牙功能，以 mt7922 為例)：**

    ```bash
    opkg install kmod-mt7922-firmware
    ```

7.  **安裝 wpa\_supplicant (用於連接 WiFi 網路)：**

    ```bash
    opkg install wpa-supplicant
    ```

8.  **安裝 hostapd (用於建立 WiFi 熱點)：**

    ```bash
    opkg install hostapd
    ```

**注意事項：**

  * 請確保您的 Proxmox VE 環境已正確設定，例如網路設定、磁碟空間等。
  * 在執行腳本前，建議先備份相關設定，以防發生意外。
  * OpenWrt 安裝完成後，請根據您的需求進行詳細設定，例如網路配置、防火牆設定等。
  * 安裝無線網卡驅動和韌體時，請務必根據您的無線網卡型號選擇正確的軟體包。

**其他資源：**

  * Proxmox VE 官方網站：[https://www.proxmox.com/proxmox-ve](https://www.google.com/url?sa=E&source=gmail&q=https://www.proxmox.com/proxmox-ve)
  * OpenWrt 官方網站：[https://openwrt.org/](https://www.google.com/url?sa=E&source=gmail&q=https://openwrt.org/)

希望本指南能幫助您順利設定 Proxmox VE 環境！
