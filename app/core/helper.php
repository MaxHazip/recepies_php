<?php

function sendjson(
    array $message,
    int $code
) {

    http_response_code($code);
    header("Content-Type: application/json; charset=utf-8");

    echo json_encode(
        $message,
        JSON_UNESCAPED_UNICODE
    );

    exit;

}