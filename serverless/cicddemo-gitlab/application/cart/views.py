import logging

import boto3
from django.shortcuts import (
    render,
    redirect
)

from cart.models import (
    Item,
    ItemInCart
)

boto3.set_stream_logger('botocore', logging.INFO)


def shop(request):
    items = []
    for item in Item.scan():
        items.append(item)
    return render(request, 'items.html', {'items': items})


def cart_remove(request, id):
    cart = read_cart(request)
    del cart[id]
    write_cart(request, cart)
    return redirect('cart')


def cart_dec(request, id):
    cart = read_cart(request)
    qnt = cart.get(id, 0)
    if qnt > 0:
        cart[id] = qnt - 1
        write_cart(request, cart)
    return redirect('cart')


def cart_add(request, id):
    cart = read_cart(request)
    qnt = cart.get(id, 0)
    cart[id] = qnt + 1
    write_cart(request, cart)
    return redirect('cart')


def cart(request):
    cart = read_cart(request)
    cart_with_items = []
    total_price = 0
    for item_id in cart:
        qnt = cart[item_id]
        item = Item.get(id=item_id)
        item_in_cart = ItemInCart(item, qnt)
        cart_with_items.append(item_in_cart)
        total_price += item_in_cart.total_price
    return render(request, 'cart.html', {'items': cart_with_items, 'total_price': total_price})


def read_cart(request):
    cart_str = request.session.get('cart', '')
    cart = dict()
    for item_and_qnt in cart_str.split(','):
        arr = item_and_qnt.split(':')
        if len(arr) != 2:
            continue
        item_id = arr[0]
        quantity = int(arr[1])
        cart[item_id] = quantity
    return cart


def write_cart(request, cart):
    cart_str = ''
    for item_id in cart:
        qnt = cart[item_id]
        if qnt <= 0:
            continue
        cart_str += item_id + ':' + str(qnt) + ','
    request.session['cart'] = cart_str
