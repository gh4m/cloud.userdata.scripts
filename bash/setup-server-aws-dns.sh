#!/bin/bash
set -eux

##
## setup dns
##

## need to pass args as this script is setup as cron to update
## AWS DNS for this cloudvpn server on stop/start public IP change
WG_CLOUDVPN_WGS1_HOSTNAME=$1
WG_CLOUDVPN_WGS1_DOMAIN_NAME=$2
WG_CLOUDVPN_WGS1_FQDN=${WG_CLOUDVPN_WGS1_HOSTNAME}.${WG_CLOUDVPN_WGS1_DOMAIN_NAME}
AWS_ROUTE53_ZONEID_PRIVATE=$3
AWS_ROUTE53_ZONEID_PUBLIC=$4
WG_CLOUDVPN_PUBL_IP_ADDR=$(curl http://169.254.169.254/latest/meta-data/public-ipv4)
WG_CLOUDVPN_PRIV_IP_ADDR=$(curl http://169.254.169.254/latest/meta-data/local-ipv4)

## in /tmp so file is removed on reboot or stop/start
AWS_DNS_PUBLIC_IP_FILE=/tmp/aws-public-ip.txt
if [[ ! -f "${AWS_DNS_PUBLIC_IP_FILE}" ]]
then

route53jsonprivate="/var/tmp/route53private.json"
cat << EOF > $route53jsonprivate
{
  "Comment": "setup private hostname",
  "Changes": [
    {
      "Action": "UPSERT",
      "ResourceRecordSet": {
        "Name": "${WG_CLOUDVPN_WGS1_FQDN}",
        "Type": "A",
        "TTL": 300,
        "ResourceRecords": [
			{
			  "Value": "${WG_CLOUDVPN_PRIV_IP_ADDR}"
			}
        ]
      }
    }
  ]
}
EOF
aws route53 change-resource-record-sets --hosted-zone-id $AWS_ROUTE53_ZONEID_PRIVATE --change-batch file://$route53jsonprivate

route53jsonpublic="/var/tmp/route53public.json"
cat << EOF > $route53jsonpublic
{
  "Comment": "setup public hostname",
  "Changes": [
    {
      "Action": "UPSERT",
      "ResourceRecordSet": {
        "Name": "${WG_CLOUDVPN_WGS1_FQDN}",
        "Type": "A",
        "TTL": 300,
        "ResourceRecords": [
			{
			  "Value": "${WG_CLOUDVPN_PUBL_IP_ADDR}"
			}
        ]
      }
    }
  ]
}
EOF
aws route53 change-resource-record-sets --hosted-zone-id $AWS_ROUTE53_ZONEID_PUBLIC --change-batch file://$route53jsonpublic

## set file so will not rerun unless server rebooted or stopped/started
echo "${WG_CLOUDVPN_PUBL_IP_ADDR}" > ${AWS_DNS_PUBLIC_IP_FILE}

fi
