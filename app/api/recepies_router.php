<?php

require_once __DIR__ . "/../core/helper.php";

function get_json_data() {

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

$path = parse_url(
    $_SERVER["REQUEST_URI"],
    PHP_URL_PATH
);

if (
    $path == "/register" || $path == "/auth"
) {

    require __DIR__ . "/auth.php";
    return true;

}

http_response_code(404);
header("Content-Type: application/json; charset=utf-8");

echo json_encode(
    [
        "messege" => "Route not found"
    ],
    JSON_UNESCAPED_LINE_TERMINATORS
);

return true;