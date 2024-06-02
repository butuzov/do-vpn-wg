# ---- Terraform ---------------------------------------------------------------

terraform {
  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "2.28.0"
    }

  }
}

# ---- Vars --------------------------------------------------------------------

variable "do_token" {}

variable "pkey" {
  description = "Digital Ocean SSH private key path"
  default     = "~/.ssh/id_rsa"
}

resource "digitalocean_ssh_key" "default" {
  name       = "publick_key"
  public_key = file("~/.ssh/id_rsa.pub")
}

# ---- Providers ---------------------------------------------------------------

provider "digitalocean" {
  token = var.do_token
}

# ---- Main --------------------------------------------------------------------

resource "local_file" "server_config" {

  content = templatefile("${path.module}/templates/config_server.tftpl", {
    client_pub_key     = trimspace(file("${path.module}/configs/client_public_key")),
    server_private_key = trimspace(file("${path.module}/configs/server_private_key"))
  })
  filename = "${path.module}/configs/wg0.server.conf"
}

resource "local_file" "peer_config" {
  depends_on = [digitalocean_droplet.wg]

  content = templatefile("${path.module}/templates/config_peer.tftpl", {
    ip                 = "10.0.0.2",
    client_private_key = trimspace(file("${path.module}/configs/client_private_key")),
    server_ip          = digitalocean_droplet.wg[0].ipv4_address,
    server_pub_key     = trimspace(file("${path.module}/configs/server_public_key")),
  })
  filename = "${path.module}/configs/wg0.conf"
}

resource "digitalocean_droplet" "wg" {
  count  = 1
  image  = "ubuntu-20-04-x64"
  name   = "wg-${count.index + 1}"
  region = "nyc1" //
  size   = "s-1vcpu-512mb-10gb"

  ssh_keys = [digitalocean_ssh_key.default.fingerprint]
}

resource "null_resource" "bootstrap" {
  depends_on = [digitalocean_droplet.wg, local_file.peer_config, local_file.server_config]

  connection {
    type        = "ssh"
    private_key = file("~/.ssh/id_rsa")
    host        = digitalocean_droplet.wg[0].ipv4_address
    user        = "root"
    timeout     = "1m"
  }

  provisioner "remote-exec" {
    inline = [
      "sed -i -r 's/^#.*_forward.*/net.ipv4.ip_forward=1/' /etc/sysctl.conf",
      "sed -i -r 's/^#.*[.]forward.*/net.ipv6.conf.all.forwarding=1/' /etc/sysctl.conf",
      "sysctl -p",
      "echo 1 > /proc/sys/net/ipv4/ip_forward",
      "echo 1 > /proc/sys/net/ipv6/conf/all/forwarding"
    ]
  }

  provisioner "remote-exec" {
    inline = [
      "sleep 60",
      "add-apt-repository -y ppa:wireguard/wireguard",
      "apt-get update",
      "apt-get install -y wireguard"
    ]
  }

  provisioner "file" {
    source      = local_file.server_config.filename
    destination = "/etc/wireguard/wg0.conf"
  }

  # Enable WireGuard interface on startup
  provisioner "remote-exec" {
    inline = [
      "systemctl enable wg-quick@wg0",
      "systemctl start wg-quick@wg0"
    ]
  }
}

# ---- Output ------------------------------------------------------------------

output "VPS_public_ip" {
  value = digitalocean_droplet.wg.*.ipv4_address
}
