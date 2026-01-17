<?php require __DIR__.'/../src/bootstrap.php'; need_login();
if(isset($_POST['roll'])) gacha_roll($_SESSION['uid']);
?><h2>กาชา</h2>
<form method="post"><button name="roll">สุ่ม</button></form>
