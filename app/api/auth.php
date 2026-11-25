<?php
require_once __DIR__ . "/../core/helper.php";

$method = $_SERVER["REQUEST_METHOD"];

$allowed_register_methods = ["POST"];
$allowed_auth_methods = ["POST"];

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

    } else if (!is_string($data["password"])) {

        $errors["password"][] = "Field password is not string";

    } else if (trim($data["password"]) === "") {

        $errors["password"][] = "Field password is empty";

    }
    else {

        if ($mode == "register") {

            $hasLowerCase = preg_match('/[a-z]/', $data["password"]);
            $hasUpperCase = preg_match('/[A-Z]/', $data["password"]);
            $hasSpecial = preg_match('/[#_$-]/', $data["password"]);

            if (!$hasLowerCase) $errors["password"][] = "Field password has no lower case char";
            if (!$hasUpperCase) $errors["password"][] = "Field password has no upper case char";
            if (!$hasSpecial) $errors["password"][] = "Field password has no special char";
            if (mb_strlen($data["password"]) < 5) $errors["password"][] = "Field email must exceed 5";

        }

    }

    if (!array_key_exists("email", $data)) {

        $errors["email"][] = "Field email is missing";

    } else if (
        !is_string($data["email"]) 
    ) {

        $errors["email"][] = "Field email is not a string";

    } else if (trim($data["email"]) === "") {

        $errors["email"][] = "Field email is empty";

    }
    else if (
        !filter_var($data["email"], FILTER_VALIDATE_EMAIL)
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
                    "message" => "Invalid fields",
                    "errors" => $errors
                ],
                422
            );
        }    

        $hashed_password = password_hash($data["password"], PASSWORD_DEFAULT);

        $stmt = $pdo->prepare(
            "
                INSERT INTO users (email, password_hash, role)
                VALUES (:email, :hashed_password, 'user');
            "
        );

        try {
            $stmt->execute(
                [
                    "email" => trim($data["email"]),
                    "hashed_password" => $hashed_password
                ]
            );
        } catch (PDOException $e) {

            $code = $e->errorInfo[1];

            if ($code == 1062) {
                sendjson(
                    [
                        "message" => "Пользователь уже существует"
                    ],
                    422
                );
            } else {
                sendjson(
                    [
                        "message" => "Internal server error"
                    ],
                    500
                );
            }

        }

        sendjson(
            [
                "success" => true
            ],
            201
        );

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
                    "message" => "Invalid fields",
                    "errors" => $errors
                ],
                422
            );
        }

        $stmt = $pdo->prepare(
            "
                SELECT id, password_hash, role FROM users
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

            $hashed_password = password_hash("justFakePassword", PASSWORD_DEFAULT);

        } else {

            $hashed_password = $user["password_hash"];

        }

        if (!$user && !password_verify($data["password"], $hashed_password) || $user["role"] != "user") {
            sendjson(
                [
                    "message" => "Invalid data",
                    "errors" => [
                        "email" => ["Invalid credentials"]
                    ]
                ],
                422
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

        $expire = date("Y-m-d H:i:s", time() + (30 * 60));

        $stmt->execute(
            [
                "user_id" => $user["id"],
                "token" => $tokenHash,
                "expire" => $expire
            ]
        );

        $tokenId = (int)$pdo->lastInsertId();

        sendjson(
            [
                "token" => "{$tokenId}|{$secret}"
            ],
            200
        );

    }



}