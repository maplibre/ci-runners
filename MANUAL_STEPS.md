# Manual Steps

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
