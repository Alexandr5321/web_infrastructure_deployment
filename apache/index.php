<?php

$host = getenv('POSTGRES_HOST') ?: 'postgres';
$db = getenv('POSTGRES_DB');
$user = getenv('POSTGRES_USER');
$password = getenv('POSTGRES_PASSWORD');

try {
    $pdo = new PDO(
        "pgsql:host=$host;dbname=$db",
        $user,
        $password
    );

    $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);

    echo "PHP → PostgreSQL connection: OK<br>";
    echo "Database: " . $db . "<br>";
    echo "User: " . $user;

} catch (PDOException $e) {
    http_response_code(500);
    echo "Database connection failed: " . $e->getMessage();
}
