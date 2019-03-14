#!/bin/bash

architecture="x86_64"

#clib="glibc"
clib="musl"

current_url="https://a-hel-fi.m.voidlinux.org/live/current"

case "$clib" in
	musl)
		lib="musl-"
		;;
	glibc)
		lib=""
		;;
esac

platform="$architecture"

printf -v target "target-%04x%04x%04x%04x" $RANDOM $RANDOM $RANDOM $RANDOM

mkdir "$target" || exit 1
cd "$target"

printf -v release "%s" "$( curl -s "$current_url/" | sed -ne '/^<a href="void-/s/^<a href="void-.*-\([0-9]\+\).tar.xz">void.*<\/a>.*$/\1/p' | tail -1 )"
printf -v url "%s/void-%s-%sROOTFS-%s.tar.xz" "$current_url" "$platform" "$lib" "$release"
wget "$url" -O rootfs.tar.xz

release="$release"
created=$( date +%s )

cat > metadata.yaml <<EOF
architecture: x86_64
creation_date: $created
properties:
  description: Void Linux $architecture ($clib)
  os: voidlinux
  release: $release
templates:
    /etc/hostname:
        when:
            - create
            - copy
        template: hostname.tpl
    /etc/rc.local:
        when:
            - create
        template: rc.local.tpl
    /etc/rc.local.orig:
        when:
            - create
        template: rc.local.orig.tpl
    /etc/bash/bashrc.d/prompts.sh:
        when:
            - create
        template: prompts.sh.tpl
EOF

mkdir templates

cat > templates/hostname.tpl <<EOF
{{ container.name }}
EOF

cat > templates/rc.local.orig.tpl <<EOF
# Default rc.local for void; add your custom commands here.
#
# This is run by runit in stage 2 before the services are executed
# (see /etc/runit/2).
EOF
chmod 755 templates/rc.local.orig.tpl

cat > templates/rc.local.tpl <<'EOF'
#!/bin/bash

PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
export PATH

printf "Removing services:\n"
for service in agetty-tty{1,2,3,4,5,6}; do
	printf "[-] %s: " "$service"
	rm "/etc/runit/runsvdir/default/$service"
	printf "removed\n"
done

printf "Adding services:\n"
for service in dhcpcd-eth0 sshd; do
	printf "[+] %s: " "$service"
	ln -s "/etc/sv/$service" /etc/runit/runsvdir/default
	printf "added\n"
done

mv /etc/rc.local.orig /etc/rc.local

EOF

cat > templates/prompts.sh.tpl <<'EOF'
#!/bin/bash

PS1="\[\e[0;36;1m\]\u\[\e[0m\]@\[\e[36m\]\h\[\e[0m\]:\[\e[35;1m\]\w\[\e[37m\]\\\$\[\e[0m\] "

export PS1
EOF

tar cvf metadata.tar metadata.yaml templates

lxc image import metadata.tar rootfs.tar.xz --alias void

cd ..

rm -rf "$target"

