<?php

require_once __DIR__ . "/../core/helper.php";

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