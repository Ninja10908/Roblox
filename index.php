<?php
// ڕێگەدان بە گەیشتنی داتا لە هەموو شوێنێکەوە
header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json");

// وەرگرتنی داتاکان لە ڕۆبلۆکسەوە
$input = file_get_contents("php://input");
$data = json_decode($input, true);

if ($data) {
    // ئەگەر داتا هات، فایلێکی دەقی دروست بکە و ناوەڕۆکەکەی تێدا بنووسە
    $logFile = 'test_log.txt';
    $currentContent = "Data Received: " . json_encode($data) . " at " . date("Y-m-d H:i:s") . "\n";
    
    // پاشکەوتکردنی داتاکە لە ناو فایلەکە
    file_put_contents($logFile, $currentContent, FILE_APPEND);
    
    // وەڵامدانەوەی ڕۆبلۆکس بۆ ئەوەی بزانێت سەرکەوتوو بوو
    echo json_encode([
        "status" => "success",
        "message" => "Datan geisht ba Railway!",
        "received_data" => $data
    ]);
} else {
    // ئەگەر بەبێ داتا لاپەڕەکە کرایەوە
    echo json_encode([
        "status" => "waiting",
        "message" => "Chawarêi datan la Roblox-awa..."
    ]);
}
?>
