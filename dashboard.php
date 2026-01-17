<?php require __DIR__.'/../src/bootstrap.php'; need_login(); ?>
<h2>แดชบอร์ด</h2>
<p>ยอดเงิน: <?=wallet_balance($_SESSION['uid'])?></p>
<a href="/shop.php">ซื้อแพ็ก</a> | <a href="/gacha.php">กาชา</a> | <a href="/chat.php">แชท</a>
