kc config use-context gke_kbh-billeder_europe-west1-b_kbh-billeder-staging-cluster

kc exec -it -n production mongo-9ctjr -- mongodump --out=/tmp/dump

kc cp -n production mongo-9ctjr:/tmp/dump ./dump

kc config use-context gke_kbh-billeder_europe-west1-b_kbh-billeder-cluster-1

kc cp -n production ./dump mongo-9fn74:/tmp/dump

kc exec -it -n production mongo-9fn74 -- mongorestore --drop /tmp/dump

kc apply -f ../kbh-billeder-cluster-1/manifest/production/kbhbilleder.dk.yaml
