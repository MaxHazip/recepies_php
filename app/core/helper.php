<?php

function sendjson(
    array $message,
    int $code
): never {

    http_response_code($code);
    header("Content-Type: application/json; charset=utf-8");

    echo json_encode(
        $message,
        JSON_UNESCAPED_UNICODE
    );

    exit;

}

function get_json_data(): array {

    $rawbody = file_get_contents("php://input");

    $decoded = json_decode($rawbody);

    if (json_last_error() !== JSON_ERROR_NONE) {
        sendjson(
            [
                "message" => "Invalid Json"
            ],
            422
        );
    }

    if (!is_object($decoded)) {
        sendjson(
            [
                "message" => "Upper level of JSON must be an object"
            ],
            422
        );
    }
    
    return get_object_vars($decoded);

}