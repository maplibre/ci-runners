# Manual Steps

## Secrets

Place secret files in the `secrets` directory.

## macOS

Install Xcode.

**Find IP and log in**
ssh -L 5900:localhost:5900 -i maplibre-native-ci-runners.pem ec2-user@**Insert public IPv4**
Example of public IPv4: ec2-34-218-210-7.us-west-2.compute.amazonaws.com
**Set Password** (otherwise we can’t sudo / screen share)
sudo passwd ec2-user
**Install homebrew with**
/bin/bash -c “$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)”

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

## Ubuntu

Create an instance on the EC2 console. Select "maplibre-ci-runner-2023" as a key pair.