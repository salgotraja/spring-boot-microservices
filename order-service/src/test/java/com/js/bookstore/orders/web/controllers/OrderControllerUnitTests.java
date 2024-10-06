package com.js.bookstore.orders.web.controllers;

import static com.js.bookstore.orders.testdata.TestDataFactory.*;
import static org.hamcrest.Matchers.hasSize;
import static org.hamcrest.Matchers.is;
import static org.junit.jupiter.api.Named.named;
import static org.junit.jupiter.params.provider.Arguments.arguments;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.BDDMockito.given;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.js.bookstore.orders.domain.OrderService;
import com.js.bookstore.orders.domain.SecurityService;
import com.js.bookstore.orders.domain.models.*;
import com.js.bookstore.orders.testdata.TestDataFactory;
import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.*;
import java.util.stream.Stream;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.Arguments;
import org.junit.jupiter.params.provider.MethodSource;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;

@WebMvcTest(OrderController.class)
class OrderControllerUnitTests {
    @MockBean
    private OrderService orderService;

    @MockBean
    private SecurityService securityService;

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private ObjectMapper objectMapper;

    private static final String USERNAME = "Jagdish";

    @BeforeEach
    void setUp() {
        given(securityService.getLoginUserName()).willReturn(USERNAME);
    }

    @ParameterizedTest(name = "[{index}]-{0}")
    @MethodSource("createOrderRequestProvider")
    void shouldReturnBadRequestWhenOrderPayloadIsInvalid(CreateOrderRequest request) throws Exception {
        given(orderService.createOrder(eq("Jagdish"), any(CreateOrderRequest.class)))
                .willReturn(null);

        mockMvc.perform(post("/api/orders")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(request)))
                .andExpect(status().isBadRequest());
    }

    static Stream<Arguments> createOrderRequestProvider() {
        return Stream.of(
                arguments(named("Order with Invalid Customer", createOrderRequestWithInvalidCustomer())),
                arguments(named("Order with Invalid Delivery Address", createOrderRequestWithInvalidDeliveryAddress())),
                arguments(named("Order with No Items", createOrderRequestWithNoItems())));
    }

    @Test
    void shouldReturnOrdersSuccessfully() throws Exception {
        List<OrderSummary> orders = List.of(
                new OrderSummary("order-001", OrderStatus.NEW), new OrderSummary("order-002", OrderStatus.IN_PROCESS));

        when(orderService.findOrders(USERNAME)).thenReturn(orders);

        mockMvc.perform(get("/api/orders"))
                .andExpect(status().isOk())
                .andExpect(content().contentType(MediaType.APPLICATION_JSON))
                .andExpect(jsonPath("$", hasSize(2)))
                .andExpect(jsonPath("$[0].orderNumber", is("order-001")))
                .andExpect(jsonPath("$[0].status", is("NEW")))
                .andExpect(jsonPath("$[1].orderNumber", is("order-002")))
                .andExpect(jsonPath("$[1].status", is("IN_PROCESS")));

        verify(orderService).findOrders(USERNAME);
    }

    @Test
    void shouldReturnOrderSuccessfully() throws Exception {
        String orderNumber = "order-123";
        Customer customer = new Customer("John Doe", "john.doe@example.com", "1234567890");
        Address deliveryAddress = TestDataFactory.createValidAddress();
        Set<OrderItem> items = Set.of(new OrderItem("P100", "Product 1", new BigDecimal("25.50"), 1));
        LocalDateTime createdAt = LocalDateTime.now();
        String comments = "Urgent delivery";

        OrderDTO order = new OrderDTO(
                orderNumber, USERNAME, items, customer, deliveryAddress, OrderStatus.NEW, comments, createdAt);

        given(orderService.findUserOrder(USERNAME, orderNumber)).willReturn(Optional.of(order));

        mockMvc.perform(get("/api/orders/{orderNumber}", orderNumber))
                .andExpect(status().isOk())
                .andExpect(content().contentType(MediaType.APPLICATION_JSON))
                .andExpect(jsonPath("$.orderNumber", is(orderNumber)))
                .andExpect(jsonPath("$.user", is(USERNAME)))
                .andExpect(jsonPath("$.status", is("NEW")))
                .andExpect(jsonPath("$.customer.name", is("John Doe")))
                .andExpect(jsonPath("$.deliveryAddress.country", is("India")))
                .andExpect(jsonPath("$.items[0].code", is("P100")));

        verify(orderService).findUserOrder(USERNAME, orderNumber);
    }

    @Test
    void shouldThrowOrderNotFoundExceptionWhenOrderDoesNotExist() throws Exception {
        // Arrange
        String orderNumber = "invalid-order-123";
        given(orderService.findUserOrder(USERNAME, orderNumber)).willReturn(Optional.empty());

        // Act & Assert
        mockMvc.perform(get("/api/orders/{orderNumber}", orderNumber)).andExpect(status().isNotFound());

        verify(orderService).findUserOrder(USERNAME, orderNumber);
    }
}
