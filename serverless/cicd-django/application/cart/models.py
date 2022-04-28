from django.conf import settings
from dynamorm import DynaModel
from marshmallow import fields


class Item(DynaModel):
    class Table:
        resource_kwargs = {
            'endpoint_url': settings.DOCAPI_ENDPOINT
        }
        session_kwargs = {
            'region_name': 'ru-central1'
        }
        name = settings.DB_TABLE_PREFIX + 'items'
        hash_key = 'id'
        read = 25
        write = 5
        stream = None

    class Schema:
        id = fields.String()
        name = fields.String()
        price = fields.Integer()
        image_url = fields.String()


class ItemInCart:
    item = Item
    quantity = 0
    total_price = 0

    def __init__(self, item, quantity):
        self.item = item
        self.quantity = quantity
        self.total_price = item.price * quantity
