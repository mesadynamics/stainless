<html>

<head>
<title>Release Notes</title>
<meta http-equiv="content-type" content="text/html;charset=iso-8859-1">
</head>

<body style="margin:20px;">

<div style=" background-color: #eee;
-webkit-border-radius: 10px;
border: 1px solid #000;
padding: 10px;"><span style="font-family: 'LucidaGrande-Bold', 'Lucida Grande', 'Lucida Sans Unicode', sans-serif; font-size: 13px;">
Release Notes</span></div>

<div style="padding:10px">
	<span style="font-family: 'LucidaGrande', 'Lucida Grande', 'Lucida Sans Unicode', sans-serif; font-size: 12px;">

	<i>known issues</i><br />
	<ul>
		<li>switching to Stainless from Expose does not update the menubar</li>
		<li>minimizing Stainless windows to dock does not work </li>
		<li>windows take a while to close on Stainless quit</li>	
		<li>Stainless is not compatible running in separate Mission Control desktop spaces</li>
		<li>on some systems, a recent WebKit update (via Safari) causes text fields to have a black background</li>
	</ul>

	<i>version 0.8 (07/25/11, final official release)</i><br />
	<ul>
	<li>new: <b>Lion compatibility</b></li>
	<li>new: 64-bit build</li>
	<li>added: ability to stop downloads in progress</li>
	<li>added: tab from autocomplete row selects URL for editing</li>
	<li>added: 3 finger swipe gesture left/right for back/forward (use with <i>option</i> key under Lion)</li>
	<li>optimized: faster multi-process manager</li>
	<li>fixed: backward and forward menus may fail for dynamic pages</li>
	<li>fixed: failed partial downloads aren't cleaned up</li>
	</ul>
	
	<i>version 0.7.5 (11/04/09)</i><br />
	<ul>
	<li>added: url and search autocompletion</li>
	<li>added: new theme-capable UI (API available in future version)</li>
	<li>added: new tab and security preferences</li>
	<li>fixed: nested group contextual menus don't work</li>
	<li>fixed: create groups from open tabs fails when no tabs are open</li>
	<li>fixed: switching to empty tab group doesn't update bookmarks</li>
	</ul>

	
	<i>version 0.7 (09/22/09)</i><br />
	<ul>
	<li>added: save session and quit</li>
	<li>added: session restore startup preference</li>
	<li>added: download location preference</li>
	<li>added: create group from open tabs</li>
	<li>added: open group urls in tabs</li>
	<li>fixed: center/cmd/opt clicking links in frames does not work as expected</li>
<li>fixed: utility windows float over all apps</li>
	<li>fixed: bring to front layering is not consistent</li>
	<li>fixed: cross-shelf bookmark drag-and-drop moves wrong bookmark</li>
	<li>fixed: cross-shelf bookmark drag-and-drop inserts into shifted position</li>
	</ul><i>version 0.6.5 (07/07/09)</i><br />
	<ul>
	<li>added: cross-process download manager</li>
	<li>added: hold and click in back/forward buttons reveal tab history</li>
	<li>added: bookmark groups (right-click in shelf to create)</li>
	<li>added: bookmark shelf preferences</li>
	<li>fixed: cannot download files that require login credentials</li>
	<li>fixed: new windows spawned from menu items or other apps open behind other windows</li>
	<li>fixed: URLs with embedded white space result in search</li>
	<li>fixed: using back/forward causes tab favicons to be lost (0.6)</li>
	<li>fixed: ampersands not properly escaped in smartbar searches</li>
	<li>fixed: double-click is allowed for new tab, tab close, and bookmark buttons</li>
	<li>fixed: opening history window after midnight doesn't update the day filters</li>
	</ul>
	
	<i>version 0.6 (05/08/09)</i><br />
	<ul>
	<li>added: global history manager with day/search filtering, copy and delete</li>
	<li>added: bookmark title, url, tags (for future use) and icon can be changed via the Configure contextual menu item</li>
	<li>added: user preference for shutting down unresponsive tabs</li>
	<li>added: new client process launcher</li>
	<li>fixed: Stainless can get into a state where tabs will no longer open, even on relaunch/reinstall</li>
	<li>fixed: after long sessions, it is possible for saved bookmarks to completely disappear</li>
	<li>fixed: bookmarklets execute only if Safari 4 beta is installed</li>
	<li>fixed: single window mode does not focus on new tabs</li>
	<li>fixed: user agent doesn't match some sites that check for Safari (e.g. surveymonkey.com)</li>
	<li>fixed: cookie domain security is overly strict (e.g MySpace captcha)</li>
				<li>fixed: session-aware bookmarks maintain a live reference to cookies in the  session, which can be overridden by continued use of the session</li>
	</ul>
	
	<i>version 0.5.5 (04/07/09)</i><br />
	<ul>
		<li>optimized: stainless manager process now uses minimal CPU and memory</li>
		<li>fixed: stainless manager process leaks, slows down ui after very long sessions</li>
		<li>fixed: crash on new tab creation after extremely long sessions</li>
		<li>fixed: Search in Google contextual menu launches Safari</li>
		<li>fixed: cannot drag tabs into separate Spaces</li>
		<li>fixed: Stainless doesn't conform to Spaces System Preferences</li>
		<li>fixed: switching to Stainless from Spaces does not update the menubar</li>
		<li>fixed: although keyboard shortcuts work, Edit menu items are disabled</li>
		<li>fixed: non-Roman languages don't display correctly in bookmark titles</li>
		<li>fixed: too easy to drag bookmark icon during click</li>
	</ul>

	<i>version 0.5.4 (03/23/09)</i><br />
	<ul>
		<li>added: labels display bookmark titles and mouseover URL</li>
		<li>added: middle-click support for bookmark opening and tab closing</li>
		<li>fixed: after continuous use server process may slow down and use excessive CPU</li>
		<li>fixed: dragging bookmark to + does not open a new session group</li>
		<li>fixed: window switching via window menu doesn't switch spaces when needed</li>
		<li>fixed: bring to front fails when windows are in different spaces</li>
		<li>fixed: bookmarklets that use cookies or HTTP POST don't work</li>
		<li>various other minor bug fixes and enhancements</li> 
	</ul>
	
	<i>version 0.5.3 (03/08/09)</i><br />
	<ul>
		<li>fixed: javascript protocol not supported in smartbar</li>
		<li>fixed: bookmarklets don't execute in bookmark shelf</li>
		<li>fixed: fatal errors in server process cause UI hang</li>
	</ul>
	
	<i>version 0.5.2 (03/05/09)</i><br />
	<ul>
		<li>fixed: login issues at some sites (e.g. Yahoo Mail)</li>
	</ul>
	
	<i>version 0.5.1 (03/05/09)</i><br />
	<ul>
		<li>fixed: local file launching is broken</li>
	</ul>
	
	<i>version 0.5 (03/05/09)</i><br />
	<ul>
		<li>added support for parallel sessions</li>
		<li>added bookmark shelf with session-aware bookmarks</li>
		<li>added private cookie storage outside of WebKit/Safari</li>
		<li>added support for HTML5 offline database storage</li>
		<li>added single window mode</li>
		<li>added page source view</li>
		<li>added drag URL to + icon</li>
		<li>added cmd 0-9 for tab switching</li>
		<li>added status bar toggle</li>
		<li>enabled continuous spellchecking</li>
		<li>fixed window layering issues</li>
		<li>fixed window issues in Spaces</li>
		<li>fixed download issue with attachments (e.g. GMail)</li>
		<li>fixed launching out to custom protocols (e.g. iTunes)</li>
	</ul>
	
	<i>version 0.4.5 (12/10/08)</i><br />
	<ul>
		<li>added dynamic loading of WebKit nightly frameworks</li>
		<li>added cmd-shift-arrow shortcuts</li>
		<li>added proper escaping to smartbar searches</li>
		<li>fixed full-screen flash playback</li>
		<li>fixed javascript window.close notification across processes</li> 
		<li>fixed client hang issues during some javascript uploads</li>
		<li>fixed browser launch from Adobe AIR apps</li>
	</ul>
	
	<i>version 0.4 (11/12/08)</i><br />bug squashing release
	<ul>
		<li>added web inspector support</li>
		<li>added deferred plugin loading in hidden tabs</li>
		<li>fixed server certificate error handling</li>
		<li>fixed javascript window sizing across processes</li>
		<li>fixed server memory leaks</li>
		<li>fixed server runaway threads</li>
		<li>fixed client messaging collision deadlocks</li>
	</ul>

	<i>version 0.3.5 (10/30/08)</i>
	<ul>
		<li>added live find-in-page</li>
		<li>added javascript window spanning across processes</li>
		<li>added web page print</li>
		<li>fixed last window location calculation</li>
		<li>fixed preferences syncing</li>
		<li>new application icon</li>
	</ul>

	<i>version 0.3 (10/21/08)</i>
	<ul>
		<li>added standard window menu</li>
		<li>added command-tilde window switching</li>

		<li>added new tab opening with middle mouse button</li>
		<li>changed User Agent to reflect Stainless version</li>
		<li>reduced launch time</li>
		<li>reduced tab switching interval</li>
		<li>reduced window flicker during new tab and close tab</li>
		<li>removed window flicker during tab switch</li>
		<li>fixed tab-drag-to-window offset</li>
	</ul>

	<i>version 0.2.5 (10/15/08)</i>
	<ul>
		<li>added page title display to main window</li><li>added default web icon display for sites lacking a favicon</li>
		<li>added URL handlers for external calling apps</li>

		<li>added hot spare process spawning for faster tab opening</li>
		<li>added multi-threaded message dispatching in client processes</li>
		<li>fixed bring-to-front on command-tab switching</li>
		<li>fixed download issue with XHTML and other HTML rendering MIME types</li>
	</ul>

	<i>version 0.2 (10/10/08)</i>
	<ul>
	<li>added new window open on dock switch</li>
	<li>added support for webloc drop-opening</li>
	<li>added temp download support via VerifiedDownloadAgent</li>
	<li>added support for Google Gears</li>
	<li>added prioritized process scheduling</li>
	<li>optimized tab switching code</li>
	<li>fixed freeze-up due to process deadlock</li>
	</ul>

	<i>version 0.1.5 (10/01/08)</i><br />maintenance release
	<ul>
	<li>added Safari-like shortcut keys</li>
	<li>added support for mailto: scheme</li>
	<li>added support for &lt;input type=file&gt;</li>
	<li>added support for javascript alerts </li>
	<li>various bug fixes</li>
	</ul>
	
	<i>version 0.1 (09/25/08)</i><br />
	<ul>
	<li>multi-processing architecture (one process per tab)</li>
	<li>drag-and-drop tabs between windows</li>
	<li>unified address and search bar</li>
	<li>private browsing mode</li>
	</ul>

</span>	
</div>

</body>
</html>
