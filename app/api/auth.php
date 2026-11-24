<?php
require_once __DIR__ . "/recepies_router.php";

$method = $_SERVER["REQUEST_METHOD"];

$allowed_register_methods = ["POST"];
$allowed_auth_methods = ["POST"];

$auth_regex = "/auth";

/** @var PDO $pdo */ 
$pdo = require __DIR__ . "/../core/database.php";

function get_user_by_email(
    string $email,
    PDO $pdo
) {

    $stmt = $pdo->prepare(
        "
            SELECT id
            FROM users
            WHERE email = :email;
        "
    );

    $stmt->execute(
        [
            "email" => $email
        ]
    );

    $user = $stmt->fetch();

    return $user;

}

function validate_data(
    array $data,
    PDO $pdo,
    string $mode
) {

    $errors = [];

    if (!array_key_exists("password", $data)) {

        $errors["password"][] = "Field password is missing";

    } else {

        $hasLowerCase = preg_match('/[a-z]/', $data["password"]);
        $hasUpperCase = preg_match('/[A-Z]/', $data["password"]);
        $hasSpecial = preg_match('/[#_-$]/', $data["password"]);

        if (!$hasLowerCase) $errors["password"][] = "Field password has no lower case char";
        if (!$hasUpperCase) $errors["password"][] = "Field password has no upper case char";
        if (!$hasSpecial) $errors["password"][] = "Field password has no special char";

    }

    if (!array_key_exists("email", $data)) {

        $errors["email"][] = "Field email is missing";

    } else if (
        !preg_match("/[A-Za-z0-9]+[-._]*[A-Za-z0-9]+@[A-Za-z0-9]+[-]*[A-Za-z0-9]\.[A-Za-z]{2,}/", $data["email"])
    ) {

        $errors["email"][] = "Wrong format";

    } else {

        if ($mode == "register") {

            $user = get_user_by_email(
                email: $data["email"],
                pdo: $pdo
            );

            if ($user) {

                $errors["email"][] = "This email is currently in use";

            }

        }

    }

    return $errors;

}

if (
    preg_match(
        "#^/recipe-api/register$#",
        $path,
        $matches
    )
) {

    if (!in_array($method, $allowed_register_methods, true)) {
        header("Allow: " . join(", ", $allowed_register_methods));
        sendjson(
            [
                "message" => "Method not allowed"
            ],
            405
        );
    }

    if ($method == "POST") {

        $data = get_json_data();

        $errors = validate_data(
            data: $data,
            pdo: $pdo,
            mode: "register"
        );

        if ($errors) {
            sendjson(
                [
                    "errors" => $errors
                ],
                422
            );
        }    

        $hashed_password = password_hash($data["password"], PASSWORD_DEFAULT);

        $stmt = $pdo->prepare(
            "
                INSERT INTO users (email, password, role)
                VALUES (:email, :hashed_password, 'user');
            "
        );

        $stmt->execute(
            [
                "email" => $data["email"],
                "hashed_password" => $hashed_password
            ]
        );

        sendjson(
            [
                "success" => true
            ],
            201
        );

        exit;

    }

}

if (
    preg_match(
        "#^/recipe-api/auth$#",
        $path,
        $matches
    )
) {

    if (!in_array($method, $allowed_auth_methods, true)) {
        header("Allow: " . join(", ", $allowed_auth_methods));
        sendjson(
            [
                "message" => "Method now allowed"
            ],
            405
        );
    }

    if ($method == "POST") {

        $data = get_json_data();

        $errors = validate_data(
            data: $data,
            pdo: $pdo,
            mode: "auth"
        );

        if ($errors) {
            sendjson(
                [
                    "errors" => $errors
                ],
                422
            );
        }

        $stmt = $pdo->prepare(
            "
                SELECT id, password_hash FROM users
                WHERE email = :email;
            "
        );

        $stmt->execute(
            [
                "email" => trim($data["email"])
            ]
        );

        $user = $stmt->fetch();

        $hashed_password = "";

        if (!$user) {

            $hashed_password = "justFakePassword";

        } else {

            $hashed_password = $user["password_hash"];

        }

        if (!$user || !password_verify($data["password"], $hashed_password) || $data["role"] != "user") {
            sendjson(
                [
                    "message" => "No such email or wrong password"
                ],
                401
            );
        }

        $secret = bin2hex(random_bytes(32));
        $tokenHash = hash("sha256", $secret);

        $stmt = $pdo->prepare(
            "
                INSERT INTO api_tokens (user_id, token_hash, expires_at)
                VALUES (:user_id, :token, :expire);
            "
        );

        $expire = time() + (30 * 60);

        $stmt->execute(
            [
                "user_id" => $user["id"],
                "token" => $tokenHash,
                "expire" => $expire
            ]
        );

        $tokenId = (int)$pdo->lastInsertId();

        $get_stmt = $pdo->prepare(
            "
                SELECT id, token_hash
                FROM api_tokens
                WHERE id = :token_id
            "
        );

        $get_stmt->execute(
            [
                "token_id" => $tokenId
            ]
        );

        $token = $get_stmt->fetch();

        sendjson(
            [
                "token" => "{$token['id']} | {$token['token_hash']}"
            ],
            200
        );

    }



}