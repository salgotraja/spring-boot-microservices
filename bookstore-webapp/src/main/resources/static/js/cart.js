document.addEventListener('alpine:init', () => {
    Alpine.data('initData', () => ({
        cart: { items: [], totalAmount: 0 },
        orderForm: {
            customer: {
                name: "Jagdish",
                email: "jagdishsal@gmail.com",
                phone: "999999999999"
            },
            deliveryAddress: {
                addressLine1: "2206",
                addressLine2: "Mantova",
                city:"Noida",
                state: "UP",
                zipCode: "201301",
                country: "India"
            }
        },

        init() {
            updateCartItemCount();
            this.loadCart();
            this.cart.totalAmount = getCartTotal();
        },
        loadCart() {
            this.cart = getCart()
        },
        updateItemQuantity(code, quantity) {
            updateProductQuantity(code, quantity);
            this.loadCart();
            this.cart.totalAmount = getCartTotal();
        },
        removeCart() {
            deleteCart();
        },
        createOrder() {
            let order = Object.assign({}, this.orderForm, {items: this.cart.items});
            console.log("Order ", order);

            $.ajax ({
                url: 'http://localhost:8989/orders/api/orders',
                type: "POST",
                dataType: "json",
                contentType: "application/json",
                data : JSON.stringify(order),
                success: (resp) => {
                    console.log("Order Resp:", resp)
                    this.removeCart();
                    //alert("Order placed successfully")
                    window.location = "/orders/"+resp.orderNumber;
                }, error: (err) => {
                    console.log("Order Creation Error:", err)
                    alert("Order creation failed")
                }
            });
        },
    }))
});