<html>

<head>
<title>Updates</title>
<meta http-equiv="content-type" content="text/html;charset=iso-8859-1">
</head>

<body style="margin:20px;">

<div style=" background-color: #eee;
-webkit-border-radius: 10px;
border: 1px solid #000;
padding: 10px;"><span style="font-family: 'LucidaGrande-Bold', 'Lucida Grande', 'Lucida Sans Unicode', sans-serif; font-size: 13px;">
Check for Updates</span></div>

<div style="padding:10px">
	<span style="font-family: 'LucidaGrande', 'Lucida Grande', 'Lucida Sans Unicode', sans-serif; font-size: 12px;">
	
<?php
function beginsWith( $str, $sub ) {
   return ( substr( $str, 0, strlen( $sub ) ) == $sub );
}
function endsWith( $str, $sub ) {
return ( substr( $str, strlen( $str ) - strlen( $sub ) ) == $sub );
}
if(beginsWith($_REQUEST['v'], '0.8'))
echo "Your version of Stainless is up to date.  There are no updates available at this time.";
else
echo "<p>A new version of Stainless (0.8) is available to download directly from this <a href='http://www.stainlessapp.com/software/Stainless.zip'>link</a>.</p><p>The release notes for all updates can be viewed at the Stainless <a href='http://www.stainlessapp.com/doc/about_notes.php'>release notes</a> page.</p>";
if($_REQUEST['v'] == '0.1' || $_REQUEST['v'] == '0.1.5')
echo "<p>Although your version of Stainless doesn't have a download manager, you can still download the update by right-clicking (or control-clicking) the link above and selecting <b>Open Link in Default Browser</b> from the popup menu.</p>";

?>
</span>	
</div>

</body>
</html>
