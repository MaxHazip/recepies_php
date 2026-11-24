<?php

$envPath = __DIR__ . "../../.env";

if (file_exists($envPath)) {

    $vars = parse_ini_file($envPath, false, INI_SCANNER_TYPED);
    foreach ($vars as $key => $value) {

        $_ENV[$key] = $value;
        putenv("$key=$value");

    }   

}