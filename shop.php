<?php require __DIR__.'/../src/bootstrap.php'; need_login();
if(isset($_POST['buy'])) buy_pack($_SESSION['uid'], $_POST['buy']);
$packs = get_packs();
?><h2>ร้าน</h2>
<?php foreach($packs as $p): ?>
<form method="post"><button name="buy" value="<?=$p['id']?>">ซื้อ <?=$p['name']?> <?=$p['price']?></button></form>
<?php endforeach ?>
