matchbox_http_endpoint = "http://192.168.14.70:8080"
matchbox_rpc_endpoint = "192.168.14.70:8081"
ssh_authorized_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDdAx40wbnT5SHE0vt3vSsLiuXyjbx5PdhRgZ0jHJTgSqdQEEGalr0u28o/hQJpIyTSNfYETEcdY1nBMbrwviv2WPp2A7QFAZF8eq0Tp4U0x1/8coSgXOyDnMUbDaFlS+b6CUcsEXsvRA1yzvBNoJ4tbmLozY/5IL4Bu9pcd8CZAR2eBkSwQ0j3gjgP+2StsIOqsba1A4FugilxQbdkQ7hRa89Rt0j92rGTEt+AzD9zgWp6VCiwumj7OiwTFbhZ/+OYA18XMQjuIb8O0RSBxQm6RDmF9b1+MFp882ZHRVK9S/FeCe0peErgmPFOjgiIxpqUzJu25rpKm7i77x8lkfOn bicnic@travelers.bicnic.fr"

cluster_name = "kube-home"
container_linux_version = "1353.8.0"
container_linux_channel = "stable"

# Machines
controller_names = ["knode1"]
controller_macs = ["08:00:27:32:CF:9A"]
controller_domains = ["knode1.home.fossar.net"]
worker_names = []
worker_macs = []
worker_domains = []

# Bootkube
k8s_domain_name = "knode1.home.fossar.net"
asset_dir = "assets"

# Optional (defaults)
cached_install = "true"
install_disk = "/dev/sda"
