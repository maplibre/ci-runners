# MapLibre CI Runners

This repository contains information about how the CI runners are set up.

## macOS

As of January 6, 2023, the macOS-based CI runners for MapLibre GL Native have some manual steps for setting up (see current `./MANUAL_STEPS.md` for details). Some parts of setting up macOS CI runners are hard to automate fully, most notably installing Xcode. 

Most configuration should be done in an automated way:

- To easily keep the runners in sync without manually applying each change to each server.
- To be able to document changes.
- To more easily upgrade to a new macOS version (AWS does not support macOS version upgrades currently, you have to set up a new macOS box).

An infrastructure as code tool called Ansible helps us with this. You write declarative YAML and Ansible will execute SSH commands to hosts as needed to achieve the desired state. Ansible has the concept of an [inventory](https://docs.ansible.com/ansible/latest//inventory_guide/intro_inventory.html) which is a list of hosts, where each host may belong to a particular group. The inventory is in the file named `inventory`. That is why you need to add the `-i inventory` flag to all commands.

You need to pass a pattern to Ansible that matches one or more hosts to run the command against. For example, you can use the `macos` group.

```
$ ansible macos --list-hosts -i inventory
```

You can run an ad-hoc command on all hosts in the `macos` group like so:

```
$ ansible macos -a '/usr/bin/xcodebuild -version' -i inventory
```

This should print the installed Xcode version for each host. This works because the [command module](https://docs.ansible.com/ansible/latest/collections/ansible/builtin/command_module.html) is used by default (`-m command`) and using `-a <cmd>` you pass the command to it as an argument.

To make changes it is better to record changes in what Ansible calls a [Playbook](https://docs.ansible.com/ansible/latest/playbook_guide/playbooks_intro.html). Run the `macos.yaml` Playbook as follows:


```
$ ansible-playbook -i inventory macos.yaml
```

See `requirements.yml` to install the required 'roles'.

## Ubuntu

```
$ ansible-playbook -i inventory ubuntu.yaml
```

## Certificates

You may find it helpful to set up SSH certificates by adding the following configuration to your `~/.ssh/config`:

```
Host ec2-34-218-210-7.us-west-2.compute.amazonaws.com ec2-18-236-103-245.us-west-2.compute.amazonaws.com
	IdentityFile ~/cert/maplibre-native-ci-runners.pem

Host ec2-3-80-132-4.compute-1.amazonaws.com
	IdentityFile ~/cert/maplibre-ci-runner-virginia.pem

Host 3.88.231.170
	User ubuntu
	IdentityFile ~/cert/maplibre-ci-runner-2023.pem
```

