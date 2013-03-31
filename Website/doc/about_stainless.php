<html>

<head>
<title>About Stainless</title>
<meta http-equiv="content-type" content="text/html;charset=iso-8859-1">
</head>

<body style="margin:20px;">

<div style=" background-color: #eee;
-webkit-border-radius: 10px;
border: 1px solid #000;
padding: 10px;"><span style="font-family: 'LucidaGrande-Bold', 'Lucida Grande', 'Lucida Sans Unicode', sans-serif; font-size: 13px;">
About Stainless</span></div>

<table>
<tr>
<td height="160">
<?php
if($_REQUEST['v'] == '0.1' || $_REQUEST['v'] == '0.1.5' || $_REQUEST['v'] == '0.2' || $_REQUEST['v'] == '0.2.5' || $_REQUEST['v'] == '0.3')
echo '<img style="padding:20px;" src="../Media/oldicon128.png" />';
else
echo '<img style="padding:20px;" src="../Media/icon128.png" />';
?>
</td>
<td><p  style="padding:20px;"><span style=" font-family: 'LucidaGrande-Bold', 'Lucida Grande', 'Lucida Sans Unicode', sans-serif; font-size: 14px;" >
Stainless
<?php
echo $_REQUEST['v'];
?>
</span><br /><br />


<span style=" font-family: 'LucidaGrande', 'Lucida Grande', 'Lucida Sans Unicode', sans-serif; font-size: 12px;" >

Copyright &copy; 2008-2013 Danny Espinoza<br /><br />

<?php
if($_REQUEST['v'] == '0.1' || $_REQUEST['v'] == '0.1.5' || $_REQUEST['v'] == '0.2' || $_REQUEST['v'] == '0.2.5' || $_REQUEST['v'] == '0.3')
echo 'Application icon based on a photograph by <a  href="http://www.properspective.com/">David Pollitt</a>.  Used with permission.<br /><br />';
else if($_REQUEST['v'] == '0.3.5' || $_REQUEST['v'] == '0.4' || $_REQUEST['v'] == '0.4.5')
echo 'Application icon designed and created by <a href="mailto:booglesthecat@gmail.com">Rodolfo Lopez</a> for Mesa Dynamics.<br /><br />';
else {
echo 'Some portions (MAAttachedWindow) by <a href="http://mattgemmell.com/">Matt Gemmell</a>.<br /><br />';
echo 'Special thanks to Tony Arnold, Evan Schoenberg, Joe Ranieri, Alexander Clauss and the various contributors to CGSPrivate for their direct and indirect help, code snippets and insight.<br /><br />';
echo 'Application icon designed and created by <a href="mailto:booglesthecat@gmail.com">Rodolfo Lopez</a>.<br /><br />';
}
?>


More information available at the Stainless <a href="http://www.stainlessapp.com/doc/about_welcome.php">welcome</a> page, <a href="http://www.stainlessapp.com/doc/about_notes.php">release notes</a> page and the Stainless <a href="http://www.stainlessapp.com"> web site</a>.

</span>
</td>
</tr>
</table>

</body>
</html>
