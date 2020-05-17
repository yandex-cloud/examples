
module "iot-vpc" {
  source       = "./modules/vpc"
  network_name = "iot-network"
  subnets = {
    "iot-data-subnet" : {
      zone           = var.yc_main_zone
      v4_cidr_blocks = ["10.0.1.0/24"]
    }
  }
}


module "managed_pgsql_iot_testing" {

  source       = "./modules/mdb-postgresql"
  cluster_name = "iot_testing"
  network_id   =  module.iot-vpc.vpc_network_id
  description  = "IoT testing PostgreSQL database"
  labels = {
    env        = "iot",
    deployment = "terraform"
  }
  environment        = "PRESTABLE"
  resource_preset_id = "b2.medium"
  disk_size          = 50

  hosts = [
    {
      zone             = var.yc_main_zone
      subnet_id        = module.iot-vpc.subnet_ids_by_names["iot-data-subnet"]
      assign_public_ip = true
    }
  ]
  users = [
    {
      name     = "iot_db_user"
      password = random_password.password.result
    }
  ]
  databases = [
    {
      name  = var.iot_db_name
      owner = "iot_db_user"
    }
  ]
  user_permissions = {
    "iot_db_user" : [
      {
        database_name = var.iot_db_name
      }
    ]}

}