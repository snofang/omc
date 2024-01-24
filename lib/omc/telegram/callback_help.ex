defmodule Omc.Telegram.CallbackHelp do
  use Omc.Telegram.CallbackQuery
  import Omc.Gettext

  @impl true
  def get_text(_args) do
    ~s"""
    __*#{gettext("Installation & Configuration Guide")}*__ 

    #{gettext("In order to establish a secure connection using OpenVPN, it is essential to install the OpenVPN client on your platform and import the necessary configuration file __.ovpn__. This section will guide you through the process, ensuring a seamless setup.")}

    #{gettext("Firstly, you need to download and install the appropriate OpenVPN client for your platform. Visit the official OpenVPN [website](www.openvpn.net) and navigate to the *Downloads* section. Choose the version compatible with your operating system, whether it be Windows, macOS, Linux, or mobile platforms such as iOS or Android. Also some direct donwload sources provided at the end of this guide for references.")}

    #{gettext("Once the installation is complete, locate the downloaded __.ovpn__ configuration file that corresponds to your __Account__. This file contains all the necessary settings for establishing a secure connection. It is accessible from __Accounts -> Account Name__ menu.")}

    #{gettext("Next, open your newly installed OpenVPN client and look for an option to import or add a new connection profile. Select this option and browse for the .ovpn configuration file you previously downloaded. Importing this file will automatically populate all required settings in your client application.")}

    #{gettext("After importing the config file successfully, you should now see it listed as a connection profile within your OpenVPN client. You can then select this profile and initiate a connection with just a click of a button.")}

    #{gettext("By following these steps carefully, you will be able to install an OpenVPN client on your platform and effortlessly import a .ovpn configuration file for establishing secure connections with ease and peace of mind.")}


    __*#{gettext("Direct Download Resources")}*__
    _*#{gettext("Android")}*_
    [#{gettext("OpenVPN for Android - GitHub")}](https://github.com/schwabe/ics-openvpn/releases/download/v0.7.51/ics-openvpn-0.7.51.apk)
    [#{gettext("OpenVPN for Android - Google Play")}](https://play.google.com/store/apps/details?id=de.blinkt.openvpn&hl=en&gl=US)
    [#{gettext("OpenVPN Connect - Google Play")}](https://play.google.com/store/apps/details?id=net.openvpn.openvpn&hl=en_US)
    _*#{gettext("IOS")}*_
    [#{gettext("OpenVPN Connect – OpenVPN App")}](https://apps.apple.com/us/app/openvpn-connect-openvpn-app/id590379981)
    """
  end

  @impl true
  def get_markup(_args) do
    [
      [
        %{text: gettext("Home"), callback_data: "Main"},
        %{text: gettext("Accounts"), callback_data: "Accounts"}
      ]
    ]
  end
end
