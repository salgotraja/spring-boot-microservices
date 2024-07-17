package com.js.bookstore.orders.domain;

import com.js.bookstore.orders.domain.models.OrderStatus;
import com.js.bookstore.orders.domain.models.OrderSummary;
import java.util.List;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.stereotype.Repository;

@Repository
interface OrderRepository extends JpaRepository<OrderEntity, Long> {
    List<OrderEntity> findByStatus(OrderStatus status);

    Optional<OrderEntity> findByOrderNumber(String orderNumber);

    default void updateOrderStatus(String orderNumber, OrderStatus status) {
        OrderEntity order = this.findByOrderNumber(orderNumber).orElseThrow();
        order.setStatus(status);
        this.saveAndFlush(order);
    }

    @Query(
            """
        SELECT new com.js.bookstore.orders.domain.models.OrderSummary(o.orderNumber, o.status)
        FROM OrderEntity o
        WHERE o.userName = :userName
        """)
    List<OrderSummary> findByUserName(String userName);

    @Query(
            """
           SELECT o
           FROM OrderEntity o LEFT JOIN FETCH o.items
           WHERE o.userName = :userName AND o.orderNumber = :orderNumber
          """)
    Optional<OrderEntity> findByUserNameAndOrderNumber(String userName, String orderNumber);
}
