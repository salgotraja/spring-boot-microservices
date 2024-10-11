document.addEventListener('alpine:init', () => {
    Alpine.data('initData', (pageNo) => ({
        pageNo: pageNo,
        products: {
          data: []
        },
        init() {
            console.log("Page No: ", pageNo);
            this.loadProducts(this.pageNo);
        },
        loadProducts(pageNo) {
            console.log("Load products page: ", pageNo);
            $.getJSON("http://localhost:8989/catalog/api/products?page="+pageNo, (response) => {
                console.log("Product Response: ", response);
                this.products = response;
            })
        }
    }))
})