package com.js.bookstore.webapp.web.controllers;

import com.js.bookstore.webapp.clients.catalog.CatalogServiceClient;
import com.js.bookstore.webapp.clients.catalog.PagedResult;
import com.js.bookstore.webapp.clients.catalog.Product;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseBody;

@Controller
class ProductController {
    private static final Logger logger = LoggerFactory.getLogger(ProductController.class);

    private final CatalogServiceClient catalogServiceClient;

    ProductController(CatalogServiceClient catalogServiceClient) {
        this.catalogServiceClient = catalogServiceClient;
    }

    @GetMapping("/products")
    String showProductsPage(@RequestParam(name = "page", defaultValue = "1") int page, Model model) {
        model.addAttribute("pageNo", page);
        return "products";
    }

    @GetMapping("/api/products")
    @ResponseBody
    PagedResult<Product> products(@RequestParam(name = "page", defaultValue = "1") int page, Model model) {
        logger.info("Fetching products for page: {}", page);
        return catalogServiceClient.getProducts(page);
    }
}
