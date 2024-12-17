package com.example.demo.controller

import org.springframework.web.bind.annotation.GetMapping
import org.springframework.web.bind.annotation.RestController

@RestController
class DemoController {

    @GetMapping("/")
    fun home(): String = "home"

    @GetMapping("/hello")
    fun hello(): String = "hello"

    @GetMapping("/health")
    fun health(): String = "ok"
}
