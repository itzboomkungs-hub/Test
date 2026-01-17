<?php require __DIR__.'/../src/bootstrap.php'; 
if($_POST){ auth_login($_POST['u'],$_POST['p']); }
?><form method="post"><h2>เข้าสู่ระบบ</h2>
<input name="u" placeholder="ผู้ใช้"><input name="p" type="password" placeholder="รหัส">
<button>เข้า</button></form>
