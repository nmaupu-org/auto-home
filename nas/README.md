# Bootstrap

As of 2024, I migrated home nas to Truenas Scale (k8s with k3s instead of jails + debian os).
iX Systems tries to make everything using the GUI, this is unacceptable so we will be using argocd!

## Preamble

Install gcloud and create a service account for cert-manager DNS-01 challenge solving:

```sh
PROJECT_ID="..."
gcloud iam service-accounts create home-dns01-solver --display-name "home-dns01-solver"
gcloud projects add-iam-policy-binding $PROJECT_ID --member serviceAccount:home-dns01-solver@$PROJECT_ID.iam.gserviceaccount.com --role roles/dns.admin
```

After create, key can be retrieve with the following command (this is done in Makefile automatically):

```sh
gcloud iam service-accounts keys create google-key.json --iam-account home-dns01-solver@$PROJECT_ID.iam.gserviceaccount.com
```

## Bootstrap

To bootstrap, finally execute:

```sh
GOOGLE_PROJECT_ID=... make
```
