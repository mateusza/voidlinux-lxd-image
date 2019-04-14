#!/bin/sh

set -eu

# set the following to override defaults
: ${VLXD_URL:="https://alpha.de.repo.voidlinux.org/live/current"}
: ${VLXD_ARCH:="x86_64-musl"}

target="$(mktemp -d target-XXXXXXXXXXXX)"
trap 'rm -rf -- "${target}"' EXIT
trap 'rm -rf -- "${target}"; exit 0' TERM INT HUP

release="$(curl -sL "$VLXD_URL/" | \
	sed -ne '/^<a href="void-/s/^<a href="void-.*-\([0-9]\+\).tar.xz">void.*<\/a>.*$/\1/p' | \
	tail -1)"

curl -sLo "${target}/rootfs.tar.xz" "${VLXD_URL}/void-${VLXD_ARCH}-ROOTFS-${release}.tar.xz"

created="$(date +%s)"
arch="${VLXD_ARCH%-musl}"
desc='Void Linux'
test "${arch}" = "${VLXD_ARCH}" || desc="${desc} (musl)"

cat > "${target}/metadata.yaml" <<EOF
architecture: $arch
creation_date: $created
properties:
  description: $desc
  os: void
  release: $release
templates:
    /etc/hostname:
        when:
            - create
            - copy
            - rename
        template: hostname.tpl
    /var/lib/firstboot:
        when:
            - create
        template: firstboot.tpl
    /etc/runit/core-services/99-firstboot.sh:
        when:
            - create
        template: 99-firstboot.sh.tpl
    /etc/bash/bashrc.d/prompts.sh:
        when:
            - create
        template: prompts.sh.tpl
EOF

mkdir "${target}/templates"

cat > "${target}/templates/hostname.tpl" <<'EOF'
{{ container.name }}
EOF

cat > "${target}/templates/99-firstboot.sh.tpl" <<'EOF'
[ -e /var/lib/firstboot ] || return

for service in agetty-tty{1,2,3,4,5,6}; do
	srv="/etc/runit/runsvdir/default/${service}"
	[ ! -L "$srv" ] || unlink "$srv"
done
for service in dhcpcd-eth0 sshd; do
	srv="/etc/sv/${service}"
	[ -L "$srv" ] || ln -s "$srv" /etc/runit/runsvdir/default
done

rm -f -- /var/lib/firstboot
EOF

: > "${target}/templates/firstboot.tpl"

cat > "${target}/templates/prompts.sh.tpl" <<'EOF'
#!/bin/bash
PS1="\[\e[0;36;1m\]\u\[\e[0m\]@\[\e[36m\]\h\[\e[0m\]:\[\e[35;1m\]\w\[\e[37m\]\\\$\[\e[0m\] "
EOF

cd "${target}"
tar cvf "metadata.tar" "metadata.yaml" "templates"
cd ..
lxc image import "${target}/metadata.tar" "${target}/rootfs.tar.xz" --alias void
