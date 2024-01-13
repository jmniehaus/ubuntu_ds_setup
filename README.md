This is a basic bash script to set up a new install of an Ubuntu distribution for common data-science tasks.

Right now it will ask if you want to install: 
1. R
2. Rstudio
3. intel-mkl
4. vscode
5. miniconda
6. rclone
7. texlive
8. texstudio
and then goes about installing the selected packages.

# Usage
__*This will require sudo priveleges*__
```
wget https://raw.githubusercontent.com/jmniehaus/ubuntu_ds_setup/main/ubuntu_ds_setup.sh -P ~/Downloads
chmod +x ~/Downloads/ubuntu_ds_setup.sh
[sudo] bash ~/Downloads/ubuntu_ds_setup.sh
```
