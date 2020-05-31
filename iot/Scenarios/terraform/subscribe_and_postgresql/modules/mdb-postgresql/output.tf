output "cluster_id" {
  value = "${yandex_mdb_postgresql_cluster.managed_postgresql.id}"
}

output "cluster_hosts_fqdns" {
  value = ["${yandex_mdb_postgresql_cluster.managed_postgresql.host.*.fqdn}"]
}

output "cluster_hosts_fips" {
  value = "${zipmap(yandex_mdb_postgresql_cluster.managed_postgresql.host.*.fqdn,
  yandex_mdb_postgresql_cluster.managed_postgresql.host.*.assign_public_ip)}"
}

output "cluster_users" {
  value = ["${yandex_mdb_postgresql_cluster.managed_postgresql.user.*.name}"]
}

output "cluster_users_passwords" {
  value = "${zipmap(yandex_mdb_postgresql_cluster.managed_postgresql.user.*.name,
  yandex_mdb_postgresql_cluster.managed_postgresql.user.*.password)}"
  sensitive = true
}

output "cluster_databases" {
  value = "${zipmap(yandex_mdb_postgresql_cluster.managed_postgresql.database.*.name,
  yandex_mdb_postgresql_cluster.managed_postgresql.database.*.owner)}"
}

