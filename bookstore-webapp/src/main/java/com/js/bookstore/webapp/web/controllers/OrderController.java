package com.js.bookstore.webapp.web.controllers;

import com.js.bookstore.webapp.clients.orders.*;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.*;

@Controller
class OrderController {
    private static final Logger logger = LoggerFactory.getLogger(OrderController.class);

    private final OrderServiceClient orderServiceClient;

    OrderController(OrderServiceClient orderServiceClient) {
        this.orderServiceClient = orderServiceClient;
    }

    @GetMapping("/cart")
    String cart() {
        return "cart";
    }

    /* @PostMapping("/api/orders")
    @ResponseBody
    OrderConfirmationDTO createOrder(@Valid @RequestBody CreateOrderRequest orderRequest) {
        logger.info("Creating order: {}", orderRequest);
        return orderServiceClient.createOrder(getHeaders(), orderRequest);
    }*/

    @GetMapping("/orders/{orderNumber}")
    String showOrderDetails(@PathVariable String orderNumber, Model model) {
        model.addAttribute("orderNumber", orderNumber);
        return "order_details";
    }

    /*@GetMapping("/api/orders/{orderNumber}")
        @ResponseBody
        OrderDTO getOrder(@PathVariable String orderNumber) {
            log.info("Fetching order details for orderNumber: {}", orderNumber);
            return orderServiceClient.getOrder(getHeaders(), orderNumber);
        }
    */
    @GetMapping("/orders")
    String showOrders() {
        return "orders";
    }

    /*@GetMapping("/api/orders")
    @ResponseBody
    List<OrderSummary> getOrders() {
        logger.info("Fetching orders");
        return orderServiceClient.getOrders(getHeaders());
    }*/

    /*private Map<String, ?> getHeaders() {
        String accessToken = securityHelper.getAccessToken();
        return Map.of("Authorization", "Bearer " + accessToken);
    }*/
}