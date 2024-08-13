# EasyWinPortForward
A small windows application to port foward internally and ensure the firewall access (especially useful for WSL)

![image](https://github.com/user-attachments/assets/653771f8-4b9c-45e7-bc67-9460f14d67a3)

![image](https://github.com/user-attachments/assets/9d9e7357-cd72-45ea-a58d-9614fbe231e1)


By default, WSL only has its port accesible from the host machine under localhost
This tool allows you to forward multiple ports to the network (not only for WSL) and make them visible to LAN, as well as opening them in firewall

(An overengineering of the netsh command)

You can find the source code in the repo and the exe in the releases, here: https://github.com/Venn0x/EasyWinPortForward/releases/tag/release

The WSL Port Forwarding function has an autofill button, it will detect your wsl ip and autofill it in the fields (make sure you have wsl turned on)

Compiled with https://github.com/MScholtes/PS2EXE
