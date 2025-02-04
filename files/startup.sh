#!/bin/bash

if [ -n "$VNC_PASSWORD" ]; then
	echo -n "$VNC_PASSWORD" > /.password1
	x11vnc -storepasswd $(cat /.password1) /.password2
	chmod 400 /.password*
	sed -i 's/^command=x11vnc.*/& -rfbauth \/.password2/' /etc/supervisor/conf.d/supervisord.conf
	export VNC_PASSWORD=ubuntu12
fi

if [ -n "$RESOLUTION" ]; then
	sed -i -r "s/\-screen 0 (.*)x(8|16|24|32)$/\-screen 0 ${RESOLUTION}x16/g" /usr/local/bin/xvfb.sh
fi

USER=${USER:-root}
HOME=/root
if [ "$USER" != "root" ]; then
	echo "* enable custom user: $USER"
	useradd --create-home --shell /bin/bash --user-group --groups adm,sudo $USER
	if [ -z "$PASSWORD" ]; then
		echo "  set default password to \"ubuntu\""
		PASSWORD=ubuntu
	fi
	HOME=/home/$USER
	echo "$USER:$PASSWORD" | chpasswd
	cp -r /root/{.gtkrc-2.0,.asoundrc} ${HOME}
	cp -r /root/.config ${HOME}/.config
	[ -d "/dev/snd" ] && chgrp -R adm /dev/snd
fi
sed -i "s|%USER%|$USER|" /etc/supervisor/conf.d/supervisord.conf
sed -i "s|%HOME%|$HOME|" /etc/supervisor/conf.d/supervisord.conf

# home folder
mkdir -p $HOME/.config/pcmanfm/LXDE/
ln -sf /usr/local/share/doro-lxde-wallpapers/desktop-items-0.conf $HOME/.config/pcmanfm/LXDE/
if [ -n "$FASTBOOT" ] ; then
	chown -R $USER:$USER $HOME
fi

# nginx workers
sed -i 's|worker_processes .*|worker_processes 1;|' /etc/nginx/nginx.conf

# nginx ssl
if [ -n "$SSL_PORT" ] && [ -e "/etc/nginx/ssl/nginx.key" ]; then
	echo "* enable SSL"
		sed -i 's|#_SSL_PORT_#\(.*\)443\(.*\)|\1'$SSL_PORT'\2|' /etc/nginx/sites-enabled/default
		sed -i 's|#_SSL_PORT_#||' /etc/nginx/sites-enabled/default
fi

# nginx http base authentication
if [ -n "$HTTP_PASSWORD" ]; then
	echo "* enable HTTP base authentication"
	htpasswd -bc /etc/nginx/.htpasswd $USER $HTTP_PASSWORD
		sed -i 's|#_HTTP_PASSWORD_#||' /etc/nginx/sites-enabled/default
fi

# novnc websockify
ln -s /usr/local/lib/web/frontend/static/websockify /usr/local/lib/web/frontend/static/novnc/utils/websockify
chmod +x /usr/local/lib/web/frontend/static/websockify/run

# clearup
PASSWORD=ubuntu
HTTP_PASSWORD=ubuntu12

exec /bin/tini -- /usr/bin/supervisord -n -c /etc/supervisor/supervisord.conf
