from django.urls import path

from . import views

urlpatterns = [
    path('', views.shop, name='shop'),
    path('cart', views.cart, name='cart'),
    path('cart-remove/<id>', views.cart_remove, name='cart_remove'),
    path('cart-dec/<id>', views.cart_dec, name='cart_dec'),
    path('cart-add/<id>', views.cart_add, name='cart_add'),
]
