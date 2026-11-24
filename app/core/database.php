<?php

require_once __DIR__ . "/helper.php";
require_once __DIR__ . "/env_ini.php";

$host = $_ENV["HOST"];
$dbName = $_ENV["DBNAME"];
$dbUser = $_ENV["USERNAME"];
$userPassword = $_ENV["PASSWORD"];

$dsn = "mysql:host=$host;dbname=$dbName;charset=utf8mb4";

$options = [

    PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
    PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
    PDO::ATTR_EMULATE_PREPARES => false

];

try {

    $pdo = new PDO($dsn, $dbUser, $userPassword, $options);
    return $pdo;

} catch (PDOException $e) {

    error_log($e->getMessage());

    sendjson(
        [
            "message" => "Internal server error"
        ],
        500
    );

}