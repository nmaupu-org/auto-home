.PHONY: ingress-controller
ingress-controller:
	helm upgrade --install \
		--namespace proxy \
		--set controller.service.type=NodePort \
		--set controller.service.externalTrafficPolicy=Cluster \
		--set controller.service.enableHttps=false \
		--set controller.service.nodePorts.http=30080 \
		--set rbac.create=true \
		ingco \
		stable/nginx-ingress

.PHONY: freenas-provisioner
.SILENT: freenas-provisioner
freenas-provisioner:
	helm upgrade --install \
		--namespace tools \
		--set deployment.image.tag=2.4 \
		--set freenas.username=$(shell vault read -field username secret/nas) \
		--set freenas.password=$(shell vault read -field password secret/nas) \
		--set freenas.host=$(shell vault read -field url secret/nas) \
		--set freenas.port=:443 \
		--set freenas.protocol=https \
		--set storageclass.reclaimPolicy=Retain \
		fp \
		freenas-provisioner

.PHONY: gonaomi
gonaomi:
	helm upgrade --install \
		--namespace tools \
		gon \
		gonaomi
