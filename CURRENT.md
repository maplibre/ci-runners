# Current

**Find IP and log in**
ssh -L 5900:localhost:5900 -i maplibre-native-ci-runners.pem ec2-user@**Insert public IPv4**
Example of public IPv4: ec2-34-218-210-7.us-west-2.compute.amazonaws.com
**Set Password** (otherwise we can’t sudo / screen share)
sudo passwd ec2-user
**Install homebrew with**
/bin/bash -c “$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)”
## **Install brew packages**
#### brew install tmux
#### Install nvm
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.1/install.sh | bash
add to .zshrc (following the command prompted by the command above)
#### brew install ninja
### Other packages
* sudo gem install xcpretty
### Pyenv
```bash
brew install pyenv
```
pyenv install 3.8.13
Add to .zshrc:
```bash
export PATH=$(pyenv root)/shims:$PATH
```
# operating TMUX
tmux attach-session -t “session name”
(detach “ctrl-b” and then “d”)
## **ALLOW SCREEN SHARE**  (apparently necessary to run)
sudo /System/Library/CoreServices/RemoteManagement/ARDAgent.app/Contents/Resources/kickstart -activate
**working version of above command**
`sudo /System/Library/CoreServices/RemoteManagement/ARDAgent.app/Contents/Resources/kickstart -activate -configure -access -off -restart -agent -privs -all -allowAccessFor -allUsers`
### CHANGE PARTITION DISK HARDDISK SIZE OR OTHER SYSTEM UPDATES
https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-mac-instances.html#mac-instance-updates
“Increase the size of an EBS volume on your Mac instance”
