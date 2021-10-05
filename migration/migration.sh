kubectl config use-context gke_kbh-billeder_europe-west1-b_kbh-billeder-staging-cluster

kubectl exec -it -n production mongo-9ctjr -- mongodump --out=/tmp/dump

kubectl cp -n production mongo-9ctjr:/tmp/dump ./dump

kubectl config use-context gke_kbh-billeder_europe-west1-b_kbh-billeder-cluster-1

kubectl cp -n production ./dump mongo-9fn74:/tmp/dump

kubectl exec -it -n production mongo-9fn74 -- mongorestore --drop /tmp/dump

kubectl apply -f ../kbh-billeder-cluster-1/manifest/production/kbhbilleder.dk.yaml
