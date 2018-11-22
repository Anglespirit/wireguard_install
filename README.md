# wireguard_install
对网络上流传的wireguard一键安装脚本改写，加入可控制的端口，以及防火墙控制
[WireGuard](https://www.wireguard.com/)是一款现代化的高性能VPN，易于使用，同时提供强大的安全性。WireGuard只关注通过使用公钥认证加密的网络之间提供安全连接。这意味着，与大多数VPN不同，不强制执行拓扑，因此可以通过操纵周围的网络配置来实现不同的配置。该软件具有强大的功能和灵活性，可根据您的个性化需求进行应用。

WireGuard可以使用的最简单的拓扑之一是点对点连接。在这在两台机器之间建立了安全链接，而没有中央服务器。这种类型的连接也可以在两个以上的成员之间使用，以建立网状VPN拓扑，其中每个单独的服务器可以直接与其对等体通信。由于每个主机都处于平等地位，因此这两种拓扑最适合在服务器之间建立安全消息传递，而不是使用单个服务器作为网关来路由流量

## **一键安装脚本使用**

yum -y install wget

wget -N --no-check-certificate https://raw.githubusercontent.com/Anglespirit/wireguard_install/master/wireguard_install.sh&& chmod +x wireguard_install.sh && bash wireguard_install.sh

一键安装之后，可不用继续接下来的步骤

#脚本属于新手编写，存在部分功能缺失，以及编写错误，请联系我更正，谢谢

## **安装软件**

WireGuard项目为Ubuntu系统提供了最新的软件包。在我们继续之前，我们需要在两台服务器上安WireGuard。在每台服务器上，执行以下操作。

首先，将WireGuard PPA添加到系统以配置对项目包的访问：

```javascript
sudo add-apt-repository ppa:wireguard/wireguard
```

出现提示时，按**ENTER键**将新包源添加到`apt`配置中。添加PPA后，更新本地软件包索引以提取有关新的可用软件包的信息，然后安装WireGuard内核模块和用户区组件：

```javascript
sudo apt-get update
sudo apt-get install wireguard-dkms wireguard-tools
```

接下来，我们可以开始在每台服务器上配置WireGuard。

## **创建私钥**

WireGuard VPN会使用公钥对其进行身份验证。可以通过交换公钥来建立新对等体之间的连接。

要生成私钥并将其直接写入WireGuard配置文件，请**在每台服务器上输**入以下内容：

```javascript
(umask 077 && printf "[Interface]\nPrivateKey = " | sudo tee /etc/wireguard/wg0.conf > /dev/null)
wg genkey | sudo tee -a /etc/wireguard/wg0.conf | wg pubkey | sudo tee /etc/wireguard/publickey
```

第一个命令将配置文件的初始内容写入`/etc/wireguard/wg0.conf`中，`umask`可我们创建具有受限权限的文件，而不会影响我们的常规环境。

第二个命令使用WireGuard的`wg`命令生成私钥，并将其直接写入我们的受限配置文件。我们还将密钥管输出到`wg pubkey`命令生成相关的公钥，我们将其写入名为`/etc/wireguard/publickey`的文件。在我们定义配置时，我们需要在第二台服务器上交换此文件中的密钥。

## **创建初始配置文件**

接下来，我们将在编辑器中打开配置文件以设置其他一些内容

```javascript
sudo nano /etc/wireguard/wg0.conf
```

您应该在名为`[Interface]`的部分中看到您生成的私钥。此部分包含连接本地端的配置。

### **配置接口部分**

我们需要定义此节点将使用的VPN IP地址以及它将侦听来自对等端的连接的端口。首先添加`ListenPort`和`SaveConfig`行，文件如下所示：

```javascript
[Interface]
PrivateKey = generated_private_key
ListenPort = 5555
SaveConfig = true
```

这里设置了WireGuard将侦听的端口。这可以是任何可绑定端口，但在本教程中，我们将在5555端口上为两台服务器设置VPN。将每台主机上的`ListenPort`设置为您选择的端口：

我们还将`SaveConfig`设置为`true`。这将告诉`wg-quick`服务在关机时自动将其配置保存到此文件。

> **注：**启用`SaveConfig`后，只要服务关闭，`wg-quick`服务就会覆盖`/etc/wireguard/wg0.conf`文件的内容。如果您需要修改WireGuard配置，请在编辑`/etc/wireguard/wg0.conf`文件之前关闭`wg-quick`服务，或使用`wg`命令对正在运行的服务进行更改（这些将在服务关闭时保存在文件中）。在wg-quick活动时，在服务运行时对配置文件所做的任何更改都将被覆盖。

接下来，为每个服务器添加一个唯一的地址，以便wg-quick服务可以在调出WireGuard界面时设置网络信息。我们将使用10.0.0.0/24子网作为VPN的地址空间。对于每台计算机，您需要选择此范围内的唯一地址（10.0.0.1到10.0.0.254），并使用CIDR表示法指定地址和子网。

我们将为我们的**第一台服务器**提供10.0.0.1的地址，在CIDR表示法中表示为10.0.0.1/24：

```javascript
[Interface]
PrivateKey = generated_private_key
ListenPort = 5555
SaveConfig = true
Address = 10.0.0.1/24
```

在我们的**第二台服务器上**，我们将地址定义为10.0.0.2，它给出了CIDR表示为10.0.0.2/24：

```javascript
[Interface]
PrivateKey = generated_private_key
ListenPort = 5555
SaveConfig = true
Address = 10.0.0.2/24
```

我们可以在配置文件中输入有关服务器对等体的信息，也可以稍后使用`wg`命令手动输入。如上所述，将`SaveConfig`选项设置为`true`的`wg-quick`服务将意味着最终将使用任一方法将对等信息写入文件。为了演示定义对等身份的两种方法，我们将在第二个服务器的配置文件中创建一个`[Peer]`部分。您现在可以保存并关闭**第一台**服务器（定义10.0.0.1地址的服务器）的配置文件。

### **定义对等部分**

在仍处于打开状态的配置文件中，在`[Interface]`部分的条目下创建一个名为`[Peer]`的部分。

首先将`PublicKey`设置为第一个服务器的公钥的值。 您可以通过在对方服务器上输入`cat /etc/wireguard/publickey`来找到此值。我们还将`AllowedIPs`设置为隧道内有效的IP地址。由于我们知道第一台服务器正在使用的特定IP地址，因此我们可以直接输入，以`/32`结尾来指示包含单个IP值的范围：

```javascript
[Interface]
. . .

[Peer]
PublicKey = public_key_of_first_server
AllowedIPs = 10.0.0.1/32
```

最后，我们可以将`Endpoint`设置为服务器的公共IP地址和WireGuard侦听端口（在本例中我们使用端口5555）。如果WireGuard在另一个地址上接收来自此对等方的合法流量，则会更新此值，从而允许VPN适应漫游条件。我们设置初始值，此服务器可以启动了：

```javascript
[Interface]
. . .

[Peer]
PublicKey = public_key_of_first_server
AllowedIPs = 10.0.0.1/32
Endpoint = public_IP_of_first_server:5555
```

完成后，保存并关闭文件以返回到命令提示符。

## **启动VPN并连接到对等体**

我们现在准备在每台服务器上启动WireGuard并配置两个对等体之间的连接。

### **打开防火墙并启动VPN**

首先，打开每台服务器上防火墙的WireGuard端口：

```javascript
sudo ufw allow 5555
```

现在，使用我们定义的`wg0`接口文件启动`wg-quick`服务：

sudo systemctl start wg-quick@wg0 

这将启动机器上的wg0网络接口。我们可以输入以下内容确认：

```javascript
ip addr show wg0
6: wg0: <POINTOPOINT,NOARP,UP,LOWER_UP> mtu 1420 qdisc noqueue state UNKNOWN group default qlen 1
    link/none 
    inet 10.0.0.1/24 scope global wg0
       valid_lft forever preferred_lft forever
```

我们可以使用wg工具查看有关VPN活动配置的信息：

```javascript
sudo wg
```

在没有对等定义的服务器上，显示将如下所示：

```javascript
interface: wg0
  public key: public_key_of_this_server
  private key: (hidden)
  listening port: 5555
```

在已定义对等配置的服务器上，输出还将包含以下信息：

```javascript
interface: wg0
  public key: public_key_of_this_server
  private key: (hidden)
  listening port: 5555

peer: public_key_of_first_server
  endpoint: public_IP_of_first_server:5555
  allowed ips: 10.0.0.1/32
```

要完成连接，我们现在需要使用`wg`命令将第二台服务器的对等信息添加到第一台服务器。

### **在命令行上添加缺少的对等信息**

在**第一台服务器**（不显示对等信息的服务器）上，使用以下格式手动输入对等信息。可以在第二台服务器的`sudo wg`输出中找到第二台服务器的公钥：

```javascript
sudo wg set wg0 peer public_key_of_second_server endpoint public_IP_of_second_server:5555 allowed-ips 10.0.0.2/32
```

您可以通过在第一台服务器上再次输入`sudo wg`来确认信息现在处于活动配置中：

```javascript
sudo wg
interface: wg0
  public key: public_key_of_this_server
  private key: (hidden)
  listening port: 5555

peer: public_key_of_second_server
  endpoint: public_IP_of_second_server:5555
  allowed ips: 10.0.0.2/32
```

我们的点对点连接现在应该已经可用。尝试从第一个服务器ping第二个服务器的VPN地址：

```javascript
ping -c 3 10.0.0.2
PING 10.0.0.2 (10.0.0.2) 56(84) bytes of data.
64 bytes from 10.0.0.2: icmp_seq=1 ttl=64 time=0.635 ms
64 bytes from 10.0.0.2: icmp_seq=2 ttl=64 time=0.615 ms
64 bytes from 10.0.0.2: icmp_seq=3 ttl=64 time=0.841 ms

--- 10.0.0.2 ping statistics ---
3 packets transmitted, 3 received, 0% packet loss, time 1998ms
rtt min/avg/max/mdev = 0.615/0.697/0.841/0.102 ms
```

如果一切正常，您可以通过重新启动服务将第一台服务器上的配置保存到`/etc/wireguard/wg0.conf`文件：

```javascript
sudo systemctl restart wg-quick@wg0
```

如果要在开机时启动VPN，可以通过输入以下命令在每台计算机上启用该服务：

```javascript
sudo systemctl enable wg-quick@wg0
```

现在，只要机器启动，就会自动启动VPN服务。

## **结论**

WireGuard因其灵活性，轻量级实现和现代加密技术而成为许多用例的绝佳选择。在本教程中，我们在两台Ubuntu服务器上安装了WireGuard，并将每台主机配置为与其对等方进行点对点连接的服务器。此拓扑非常适合与对等方建立服务器到服务器的通信，其中每方是相同的参与者，或者与其他服务器建立临时连接



原文来自： [腾讯云]: https://cloud.tencent.com/developer/article/1168985



