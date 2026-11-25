<?php

require_once __DIR__ . "/../core/helper.php";

$path = parse_url(
    $_SERVER["REQUEST_URI"],
    PHP_URL_PATH
);

if (
    $path == "/recipe-api/register" || $path == "/recipe-api/auth"
) {

    require __DIR__ . "/auth.php";
    return true;

}

http_response_code(404);
header("Content-Type: application/json; charset=utf-8");

echo json_encode(
    [
        "message" => "Route not found"
    ],
    JSON_UNESCAPED_LINE_TERMINATORS
);

return true;