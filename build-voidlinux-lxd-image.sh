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
            - rename
        template: hostname.tpl
    /etc/rc.firstboot:
        when:
            - create
        template: rc.firstboot.tpl
    /etc/runit/core-services/999-firstboot.sh:
        when:
            - create
        template: 999-firstboot.sh.tpl
    /etc/bash/bashrc.d/prompts.sh:
        when:
            - create
        template: prompts.sh.tpl
EOF

mkdir templates

cat > templates/hostname.tpl <<'EOF'
{{ container.name }}
EOF

cat > templates/999-firstboot.sh.tpl <<'EOF'
[[ -e /var/lib/firstboot-done ]] || bash /etc/rc.firstboot
EOF

cat > templates/rc.firstboot.tpl <<'EOF'
#!/bin/bash

for service in agetty-tty{1,2,3,4,5,6}; do
	printf -v srv "/etc/runit/runsvdir/default/%s" "$service"
	[[ -L "$srv" ]] && rm "$srv"
done
for service in dhcpcd-eth0 sshd; do
	printf -v srv "/etc/sv/%s" "$service"
	[[ -L "$srv" ]] || ln -s "$srv" /etc/runit/runsvdir/default
done

touch /var/lib/firstboot-done
EOF

cat > templates/prompts.sh.tpl <<'EOF'
#!/bin/bash
PS1="\[\e[0;36;1m\]\u\[\e[0m\]@\[\e[36m\]\h\[\e[0m\]:\[\e[35;1m\]\w\[\e[37m\]\\\$\[\e[0m\] "
EOF

tar cvf metadata.tar metadata.yaml templates

lxc image import metadata.tar rootfs.tar.xz --alias void

cd ..

rm -rf "$target"

