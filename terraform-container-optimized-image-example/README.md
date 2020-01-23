# terraform-container-optimized-image

This is a test project with Container Optimized Image configuration.

# Configuration

## Compute Instance with Container Optimized Image 

Look in ```compute_instance``` directory

Substitute local variables values in main.tf:

* Substitute your user instead of "yc-user".
* Substitute your token instead of "your YC_TOKEN".
* Substitute your folder_id instead of "your folder id".
* Substitute your availability  zone instead of "your zone".
* Substitute your subnet_id instead of "your subnet id".

## Launching Container Optimized Image
* Run ```terraform plan```, then ```terraform apply```.
* After ```terraform apply``` you will have public IPv4 address in the outputs:
   ```
   Outputs:
   external_ip = <some_IPv4>
    ```
* Access newly created virtual machine: ```ssh yc-user@<some_IPv4>```
* Make http request to your virtual machine: ```curl <some_IPv4>```.
 
  You will get in the response::
  ```
    <!DOCTYPE html>
    <html lang="en">
    <head>
        <meta http-equiv="refresh" content="3">
        <title>Yandex.Scale</title>
    </head>
    <body>
    <h1>Hello v1</h1>
    </body>
    </html>
  ```

## Creating Instance Group with Container Optimized Image

Look in ```instance_group``` directory:
* Substitute your public ssh key instead of "your public ssh key" in cloud_config.yaml.
* Substitute your token instead of "your YC_TOKEN" in main.tf.
* Substitute your folder_id instead of "your folder id".
* Substitute your zone instead of "your zone".
* Substitute your network_id instead of "your network id".
* Substitute your subnet_id instead of "your subnet id".
* Substitute your service_account_id instead of "your service account id" in main.tf with you service account authorized for this instance group.
* Substitute your instance_template.service_account_id instead of "The ID of the service account authorized for this instance".
* Substitute your zones instead of "all your availability zones".
