# Device Adoption with Bridge Network Mode

**Intended Audience**: These instructions are targeted at users who are running the controller using "bridged" networking (with ports exposed) as the controller and devices being adopted need special configuration or you will end up with devices adoption failures. If you're running in host mode or using advanced networking capabilities like using a macvlan network, you should not need to follow these instructions.

Most of what is found in this document can be found in this [TP-Link FAQ](https://www.tp-link.com/us/support/faq/4100/) on adopting devices across layer 3 networks. When you're running a controller in a container using bridged network mode, the controller has a private IP address that is not going to be accessible from your actual network. So if you do not configure your device being adopted to inform it of the controller's IP address or hostname, the controller will tell the device being adopted that it is available on an IP address on the internal Docker bridge network which isn't accessible from the device being adopted.

The steps below follow the layer 3 Inform URL instructions in their FAQ but with specific details related to how the controller runs inside a container. While the instructions don't really differ significantly, I do find the process to be slightly different than what is shown in the FAQ. For the other two methods, see the [Alternate Configuration Options](#alternate-configuration-options) section at the end of this readme.

## Configuring your device for adoption

1. Make sure you are running the latest firmware supported by your controller version before proceeding! Check the TP-Link support site for your device for compatability information.
1. If previously configured, you might want to factory reset your device being adopted.
    * I would at least advise you to do this if you follow the instructions but adoption issues persist.
1. Connect to your device's IP address using your web browser.
    * You may need to look at your DHCP server's leases that it has handed out to determine the IP address of the device. This may differ depending on your device's firmware but it's typically going to be a https connection so if your device was given `192.168.0.100`, connect to `https://192.168.0.100`.
1. Login with the default credentials.
    * In many cases, the default credentials will be `admin` / `admin`. See your device's documentation for the default credentials.
1. You may be prompted to change the username and password - go ahead and do so and record those credentials as you will need them later.
1. In most devices, you will want to navigate to `System` > `Controller Settings` and in the `Controller Inform URL` section, set the value of `Inform URL/IP Address` to just the IP address of the host running your controller. So if my controller container is running on a host with the IP of `192.168.0.200`, I would **only** enter the IP into that field. The other parameters are optional as they are only needed if the Discovery and Management ports were changed from their defaults.

Once you save this setting on your device, it should now be ready for adoption from the controller.

## Adopting your device

1. From the controller global view, go to `Devices` and click the `Add Devices` button.
1. Choose the site you wish to add your device to and check the box next to the device which should be discovered by the controller.
1. Click the `Apply` button to start adoption **which will almost certainly fail due to the credentials being changed on the device upon first login**
1. Once adoption has failed, repeat the adoption process but this time, you should be prompted for the username and password of the device.

After a minute or so, the adoption process should now be complete.

## Alternate Configuration Options

These two alternate configuration options are documented in the TP-Link FAQ linked above. Depending on your situation, they may work better for you. I have not tested these scenarios but I am assuming that the TP-Link documentation is fairly accurate.

* **DHCP Option 138** - if your DHCP server allows DHCP Option configuration, you can set `Option 138` to specify the IP address of the controller container's host instead of manually specifying the Inform URL on your device to be adopted. Adoption should then function as expected as when your device gets an IP address via DHCP, it will automatically configure the Inform URL to the value specified.
* **Discovery Utility** - you can use TP-Link's discovery utility to configure the Inform URL for you which removes some of the manual steps above. The general workflow should remain the same with adoption though.
