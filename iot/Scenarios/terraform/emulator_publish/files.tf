data "template_file" "publish_index_js" {
  template = "${file("${path.module}/publish/index.js")}"
  vars = {
    registry_id = yandex_iot_core_registry.emulator.id
    subtopic    = var.subtopic_for_publish
  }
}

data "archive_file" "publish_zip" {
  type        = "zip"
  output_path = "${path.module}/gen/publish.zip"

  source {
    content  = "${data.template_file.publish_index_js.rendered}"
    filename = "index.js"
  }

  source {
    content  = "${file("${path.module}/publish/iot_data.js")}"
    filename = "iot_data.js"
  }

  source {
    content  = "${file("${path.module}/publish/package.json")}"
    filename = "package.json"
  }
}
