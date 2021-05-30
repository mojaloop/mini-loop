#!/usr/bin/env bash
# run the mojaloop demo-mojawallet
# @ see https://github.com/mojaloop/demo-mojawallet


# various yum packages  
apt remove yarn -y 
sudo apt install curl
curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | sudo apt-key add -
echo "deb https://dl.yarnpkg.com/debian/ stable main" | sudo tee /etc/apt/sources.list.d/yarn.list
sudo apt update
sudo apt install yarn

# update package dependencies 
cd /vagrant/demo-mojawallet
rm package-lock.json
yarn

# start the OAuth2.0 server
mkdir /vagrant/logs 
./scripts/setupHydra.sh 
./scripts/setupFrontendClient.sh

cd /vagrant/demo-mojawallet/backend
npm run build
npm run start > /logs/backend.log 2>&1 &

cd /vagrant/demo-mojawallet/frontend
npm run dev > logs/frontend.log 2>&1 & 



