package com.js.bookstore.webapp.web.controllers;

import com.js.bookstore.webapp.clients.orders.*;
import com.js.bookstore.webapp.services.SecurityHelper;
import jakarta.validation.Valid;
import java.util.List;
import java.util.Map;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.*;

@Controller
class OrderController {
    private static final Logger logger = LoggerFactory.getLogger(OrderController.class);

    private final OrderServiceClient orderServiceClient;
    private final SecurityHelper securityHelper;

    OrderController(OrderServiceClient orderServiceClient, SecurityHelper securityHelper) {
        this.orderServiceClient = orderServiceClient;
        this.securityHelper = securityHelper;
    }

    @GetMapping("/cart")
    String cart() {
        return "cart";
    }

    @PostMapping("/api/orders")
    @ResponseBody
    OrderConfirmationDTO createOrder(@Valid @RequestBody CreateOrderRequest orderRequest) {
        logger.info("Creating order: {}", orderRequest);
        String accessToken = securityHelper.getAccessToken();
        Map<String, ?> headers = Map.of("Authorization", "Bearer " + accessToken);
        return orderServiceClient.createOrder(headers, orderRequest);
    }

    @GetMapping("/orders/{orderNumber}")
    String showOrderDetails(@PathVariable String orderNumber, Model model) {
        model.addAttribute("orderNumber", orderNumber);
        return "order-details";
    }

    @GetMapping("/api/orders/{orderNumber}")
    @ResponseBody
    OrderDTO getOrder(@PathVariable String orderNumber) {
        logger.info("Fetching order details for orderNumber: {}", orderNumber);
        String accessToken = securityHelper.getAccessToken();
        Map<String, ?> headers = Map.of("Authorization", "Bearer " + accessToken);
        return orderServiceClient.getOrder(headers, orderNumber);
    }

    @GetMapping("/orders")
    String showOrders() {
        return "orders";
    }

    @GetMapping("/api/orders")
    @ResponseBody
    List<OrderSummary> getOrders() {
        logger.info("Fetching orders");
        String accessToken = securityHelper.getAccessToken();
        Map<String, ?> headers = Map.of("Authorization", "Bearer " + accessToken);
        return orderServiceClient.getOrders(headers);
    }

    /*private Map<String, ?> getHeaders() {
        String accessToken = securityHelper.getAccessToken();
        return Map.of("Authorization", "Bearer " + accessToken);
    }*/
}
