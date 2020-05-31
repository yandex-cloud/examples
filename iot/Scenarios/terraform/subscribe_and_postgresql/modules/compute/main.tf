variable "labels" {
  type = map(string)
}

variable "subnet_a_id" {
  type = string
}

variable "subnet_b_id" {
  type = string
}
variable "subnet_c_id" {
  type = string
}

variable "vm_user" {
  type = string
}

resource "yandex_compute_instance" "tvm_master" {
  name        = "tvm-master"
  description = "The Master VM"

  labels = var.labels

  resources {
    cores  = 2
    memory = 4
  }

  boot_disk {
    initialize_params {
      image_id = "fd8j9nuap0vh3k1f5m8s"
      size     = 24 #GiB
      type     = "network-ssd"
    }

  }

  network_interface {
    subnet_id = var.subnet_a_id
    nat       = true
  }

  metadata = {
    ssh-keys = "${var.vm_user}:${file("~/.ssh/id_rsa.pub")}"

  }
}

resource "yandex_compute_instance" "tvm" {
  name        = "tvm"
  description = "Just a replica"

  resources {
    cores  = 4
    memory = 8
  }

  labels = var.labels

  boot_disk {
    initialize_params {
      image_id = "fd8j9nuap0vh3k1f5m8s"
      size     = 240 #GiB
      type     = "network-ssd"
    }
  }

  network_interface {
    subnet_id = var.subnet_a_id
    nat       = true
  }

  metadata = {
    ssh-keys = "${var.vm_user}:${file("~/.ssh/id_rsa.pub")}"
  }
}
