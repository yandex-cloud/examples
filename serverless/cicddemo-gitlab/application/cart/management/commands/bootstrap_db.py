import yaml
from django.conf import settings
from django.core.management.base import BaseCommand

from cart.models import Item


class Command(BaseCommand):
    help = 'Creates tables and populates them with test data'

    def handle(self, *args, **options):
        self.create_table(Item.Table)
        with open(settings.BASE_DIR / 'cart/management/commands/sample-data.yaml', 'r') as stream:
            sample_data = yaml.safe_load(stream)['items']
        for item in sample_data:
            Item.put(item)

    @staticmethod
    def create_table(table_spec):
        table = table_spec.resource.create_table(
            TableName=table_spec.name,
            KeySchema=table_spec.key_schema,
            AttributeDefinitions=table_spec.attribute_definitions,
            ProvisionedThroughput=table_spec.provisioned_throughput,
        )
        table.meta.client.get_waiter("table_exists").wait(TableName=table_spec.name)
