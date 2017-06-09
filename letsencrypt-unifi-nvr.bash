#!/bin/bash

#########
# Get the domain name supplied on the commandline
OPTIND=1         # Reset in case getopts has been used previously in the shell.

# Initialize our own variables:
domain=false
verbose=0
skip_software_install=0
install=0
renew=0

while getopts "h?vd:sir" opt; do
	case "$opt" in
	h|\?)
		show_help
		exit 0
		;;
	v)  verbose=1
		;;
	d)  domain=$OPTARG
		;;
	s)  skip_software_install=1
		;;
	i)  install=1
		;;
	r)  renew=1
		;;
	esac
done

shift $((OPTIND-1))

[ "$1" = "--" ] && shift

echo "verbose=$verbose, domain='$domain', Leftovers: $@"

if [ $domain == false ]; then
		echo "Missing required -d parameter"
		exit 1
fi

if [ $verbose == 1 ]; then
		echo "Installing Lets Encrypt with certificate for $domain"
fi


########
#Install software

if [ $install == 1 ]; then
		# This is needed for add-apt-repository to work
		apt-get update && apt-get -y install software-properties-common

		# Add letsencrypt apt repo
		add-apt-repository -y ppa:certbot/certbot

		# Install letsencrypt
		apt-get update && apt-get -y install certbot

		#### Get certificate
		# Request certificate
		certbot certonly --standalone -d $domain --register-unsafely-without-email
		
		#write out current crontab
		crontab -l > mycron
		#echo new cron into cron file
		echo "00 00 * * * /usr/local/bin/letsencrypt-unifi-nvr/letsencrypt-unifi-nvr.bash -r -d $domain" >> mycron
		#install new cron file
		crontab mycron
		rm mycron
fi


if [ $renew == 1 ]; then
		certbot renew --standalone
fi

openssl pkcs12 -export -in /etc/letsencrypt/live/$domain/fullchain.pem -inkey /etc/letsencrypt/live/$domain/privkey.pem -out /etc/letsencrypt/live/$domain/cert_and_key.p12 -name newcert -CAfile /etc/letsencrypt/live/$domain/chain.pem -caname root -password pass:ubiquiti;

keytool -importkeystore -destkeystore /var/lib/unifi-video/keystore -deststorepass ubiquiti -srckeystore /etc/letsencrypt/live/$domain/cert_and_key.p12 -srcstorepass ubiquiti -srcstoretype PKCS12

keytool -delete -keystore /var/lib/unifi-video/keystore -storepass ubiquiti -alias airvision

keytool -changealias -keystore /var/lib/unifi-video/keystore -storepass ubiquiti -alias newcert -destalias airvision

service unifi-video restart;
