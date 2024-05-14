package com.js.bookstore.orders.web.controllers;

// @Service
class RabbitMQListener {

    // @RabbitListener(queues = "${orders.new-orders-queue}")
    public void handleNewOrder(MyPayload payload) {
        System.out.println("New Order: " + payload.content());
    }

    // @RabbitListener(queues = "${orders.delivered-orders-queue}")
    public void handleDeliveredOrder(MyPayload payload) {
        System.out.println("Delivered order: " + payload.content());
    }
}
