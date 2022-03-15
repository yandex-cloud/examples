terraform {
  required_providers {
    yandex = {
      source = "yandex-cloud/yandex"
    }
  }
  required_version = ">=0.13"
}

provider "yandex" {
  token     = "t1.9euelZrNk4nPmJ6MkJvNnc7GypqWzO3rnpWalpCQzZbNnMiemYySmpjPlcbl8_dEBj5u-e9jLRky_t3z9wQ1O27572MtGTL-.9bA4ihqPzFqLwdKxpGKHSDwKIT-x1Vfo-aoezdFH5tHH24Bsl7pzzx5NbFXM1XqasChQcO906j8lRpMw8dQWAA" # Set the OAuth token. For create it use YC CLI command: yc iam create-token
  cloud_id  = "b1gkgm9daf9605njnmn8"                                                                                                                                                                       # Set the cloud ID
  folder_id = "b1gaihr2697j1dbr0mej"                                                                                                                                                                       # Set the folder ID
  zone      = "ru-central1-a"                                                                                                                                                                              # Set the availability zone, ru-central1-a xor ru-central1-b
}
