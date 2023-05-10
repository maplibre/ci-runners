# Manual Steps

## Secrets

Place secret files in the `secrets` directory.


## Creating a new EC2 instance

1. Go to the EC2 management console.
2. Click "Launch instances"
3. Select OS and instance type
4. Select `maplibre-ci-runner-2023` as key pair (this one is available in the MapLibre password manager).
5. If needed for your OS type, follow the manual steps below. Finish configuring the runner by executing te Ansible playbook.

## macOS

Install Xcode.

**Find IP and log in**
ssh -L 5900:localhost:5900 -i maplibre-native-ci-runners.pem ec2-user@**Insert public IPv4**
Example of public IPv4: ec2-34-218-210-7.us-west-2.compute.amazonaws.com
**Set Password** (otherwise we can’t sudo / screen share)
sudo passwd ec2-user
**Install homebrew with**
/bin/bash -c “$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)”

### Install certificates

After transfering the secrets, the certificates need to be imported.

```
sudo fastlane run import_certificate certificate_path:$HOME/secrets/distribution.cer keychain_path:/Library/Keychains/System.keychain keychain_password:ec2-user
sudo fastlane run import_certificate certificate_path:$HOME/secrets/development.cer keychain_path:/Library/Keychains/System.keychain
```

Enter the keychain password when prompted.

### operating TMUX

tmux attach-session -t “session name”
(detach “ctrl-b” and then “d”)

### **ALLOW SCREEN SHARE**  (apparently necessary to run)

sudo /System/Library/CoreServices/RemoteManagement/ARDAgent.app/Contents/Resources/kickstart -activate

**working version of above command**
`sudo /System/Library/CoreServices/RemoteManagement/ARDAgent.app/Contents/Resources/kickstart -activate -configure -access -off -restart -agent -privs -all -allowAccessFor -allUsers`

### CHANGE PARTITION DISK HARDDISK SIZE OR OTHER SYSTEM UPDATES

https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-mac-instances.html#mac-instance-updates
“Increase the size of an EBS volume on your Mac instance”

### Enable Automatic Login

This is needed since the macOS tests need to be run in a graphical environment (see https://github.com/maplibre/maplibre-gl-native/pull/985).

<img width="1092" alt="image" src="https://user-images.githubusercontent.com/649392/229949956-97f80f3d-9e4d-44aa-87ec-1e78ade85514.png">

### Install Provisioning Profile

1. Log in to the Apple Developer Portal and create a wildcard provisioning profile. https://developer.apple.com/account/resources/profiles/list
2. Put it in the `secrets` directory.

The provisioning profile is valid for a year and needs to be replaced after that.


#### Register Device

In addition to installing the provisioning profile, the runner needs to be registered. The UUID can be found via the command [shared here](https://apple.stackexchange.com/questions/342042/how-can-i-query-the-hardware-uuid-of-a-mac-programmatically-from-a-command-line). It will also be logged to the console if you try to use the provisioning profile on device that is not registered.

![image](https://user-images.githubusercontent.com/649392/235735852-5cb51c48-6e75-49a5-bfd7-eb7f13a2a210.png)
