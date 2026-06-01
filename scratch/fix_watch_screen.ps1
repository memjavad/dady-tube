$path = "c:\the ai\dady tube\lib\screens\watch_screen.dart"
$content = Get-Content $path
$content[76] = $content[76] -replace 'pauseBackgroundOperations\(\)', 'setPlaybackFocus(true)'
$content[82] = $content[82] -replace 'resumeBackgroundOperations\(\)', 'setPlaybackFocus(false)'
$content[93] = "      // _cacheService.resumeBackgroundOperations(); // DEFERRED FOR FOCUS"
$content | Set-Content $path
