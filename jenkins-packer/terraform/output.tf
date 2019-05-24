output "nginx_ips" {
  value = "${local.nginx_ips}"
}


output "django_ips" {
  value = "${local.django_ips}"
}


output "subnet_ids" {
  value = "${local.subnet_ids}"
}


output "folder_id" {
  value = "${var.folder_id}"
}
