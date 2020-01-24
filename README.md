# container-crypt
Script to simplify creating, mounting and unmounting an encrypted container. Requires cryptsetup (dm-crypt userspace tool) and sudo

Sets up a container and associated mount folder on first run. To setup again, delete ~/.config/container-crypt.conf

It's a bit hacky, but it does what it's supposed to for my use case. Unencrypted Linux setup with the convenience of being able to encrypt specific files inside a (un)mountable container.
