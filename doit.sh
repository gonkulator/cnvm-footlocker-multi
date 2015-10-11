#!/bin/sh
#dc mass footlocker bootstrap

vagrant up --provider=$1

#zero the host state files
#touch thehosts
#touch therunninghosts
#>thehosts
#>therunninghosts

mkdir sshconfigs
vagrant ssh-config cnvm-00 > sshconfigs/cnvm-00-sshconfig
masterip=$(cat sshconfigs/cnvm-00-sshconfig | grep HostName | awk '{print $2}')
masteruser=$(cat sshconfigs/cnvm-00-sshconfig | head -3 | grep User | awk '{print $2}')
mastersshkey=$(cat sshconfigs/cnvm-00-sshconfig | grep IdentityFile | awk '{print $2}')
masterport=$(cat sshconfigs/cnvm-00-sshconfig | head -4 | grep Port | awk '{print $2}')

ssh-keyscan -p ${masterport} -t rsa ${masterip} >> ~/.ssh/known_hosts 
scp -P ${masterport} -i ${mastersshkey} ${masteruser}@${masterip}:./id_rsa* ./thekeys
echo "Retrieved cnvm-00 ssh-keys"

targetnodes=($(cat therunninghosts | grep -v cnvm-00))

#for i in ${targetnodes[@]}; do
#	targetip=$(vagrant ssh-config $i | grep HostName | awk '{print $2}')
#	targetuser=$(vagrant ssh-config $i | head -3 | grep User | awk '{print $2}')
#	targetkey=$(vagrant ssh-config $i | grep IdentityFile | awk '{print $2}')
#	echo "Connecting to $i to do the key needful..."

for i in ${targetnodes[@]}; do
	vagrant ssh-config $i > sshconfigs/$i-sshconfig
	targetip=$(cat sshconfigs/$i-sshconfig | grep HostName | awk '{print $2}')
	targetuser=$(cat sshconfigs/$i-sshconfig | head -3 | grep User | awk '{print $2}')
	targetkey=$(cat sshconfigs/$i-sshconfig | grep IdentityFile | awk '{print $2}')
	targetport=$(cat sshconfigs/$i-sshconfig | head -4 | grep Port | awk '{print $2}')
	echo "Connecting to $i to do the key needful..."
	ssh-keyscan -p ${targetport} -t rsa ${targetip} >> ~/.ssh/known_hosts 
	ssh -p ${targetport} -i ${targetkey} ${targetuser}@${targetip} mkdir nodekeys
	scp -P ${targetport} -i ${targetkey} ./thekeys/* ${targetuser}@${targetip}:./nodekeys
	ssh -p ${targetport} -i ${targetkey} ${targetuser}@${targetip} 'sudo ~/nodekeys/keyupdate.sh'
done

keyscantargets=$(cd ./sshconfigs && for i in $(ls) ; do cat $i | head -2 | grep HostName | awk '{print $2}' ;done | xargs)

for i in ${targetnodes[@]}; do
	targetip=$(cat sshconfigs/$i-sshconfig | grep HostName | awk '{print $2}')
	targetuser=$(cat sshconfigs/$i-sshconfig | head -3 | grep User | awk '{print $2}')
	targetkey=$(cat sshconfigs/$i-sshconfig | grep IdentityFile | awk '{print $2}')
	targetport=$(cat sshconfigs/$i-sshconfig | head -4 | grep Port | awk '{print $2}')
	ssh -p ${targetport} -i ${targetkey} ${targetuser}@${targetip} "sudo ~/nodekeys/keyscanner.sh ${keyscantargets}"
done

echo "Keyscanning master to targets..."
scp -P ${masterport} -i ${mastersshkey} thekeys/keyscanner.sh ${masteruser}@${masterip}:.
ssh -p ${masterport} -i ${mastersshkey} ${masteruser}@${masterip} "sudo ~/keyscanner.sh ${keyscantargets}"

echo "Kicking off Cloud Native VM footlocker builds..."


echo "Cleaning up..."
#rm sshconfigs/*
#rm thekeys/id_rsa*
#rm thehosts
#rm therunninghosts

echo "Done."
